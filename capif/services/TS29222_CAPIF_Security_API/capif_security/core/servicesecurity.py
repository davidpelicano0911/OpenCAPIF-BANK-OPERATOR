
import hashlib
import hmac
import json
import os
import unicodedata
from datetime import datetime, timedelta

import rfc3987
from bson import json_util
from flask import current_app, request
from flask_jwt_extended import create_access_token
from pymongo import ReturnDocument

from ..core.publisher import Publisher
from ..models.access_token_claims import AccessTokenClaims
from ..models.access_token_err import AccessTokenErr
from ..models.access_token_rsp import AccessTokenRsp
from ..util import clean_empty, dict_to_camel_case, serialize_clean_camel_case
from .redis_event import RedisEvent
from .resources import Resource
from .responses import (bad_request_error, forbidden_error,
                        internal_server_error, make_response, not_found_error)

publish_ops = Publisher()

security_context_not_found_detail = "Security context not found"
api_invoker_no_context_cause = "API Invoker has no security context"


TOTAL_FEATURES = 3
SUPPORTED_FEATURES_HEX = "4"

def return_negotiated_supp_feat_dict(supp_feat):
    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]
    return {
        "Notification_test_event": True if final_supp_feat[0] == "1" else False,
        "Notification_websocket": True if final_supp_feat[1] == "1" else False,
        "SecurityInfoPerAPI": True if final_supp_feat[2] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }

class SecurityOperations(Resource):

    def __check_invoker(self, api_invoker_id):
        invokers_col = self.db.get_col_by_name(self.db.capif_invokers)

        current_app.logger.debug(
            "Checking api invoker with id: " + api_invoker_id)
        invoker = invokers_col.find_one({"api_invoker_id": api_invoker_id})
        if invoker is None:
            current_app.logger.warning("Invoker not found")
            return not_found_error(detail="Invoker not found", cause="API Invoker not exists or invalid ID")

        return None

    def __check_scope(self, scope, security_context):

        try:

            current_app.logger.debug("Checking scope")
            header = scope[0:4]
            if header != "3gpp":
                current_app.logger.warning("Bad format scope")
                token_error = AccessTokenErr(error="invalid_scope", error_description="The first characters must be '3gpp'")
                return make_response(object=clean_empty(token_error.to_dict()), status=400)

            _, body = scope.split("#")

            capif_service_col = self.db.get_col_by_name(
                self.db.capif_service_col)
            security_info = security_context["security_info"]
            aef_security_context = [info["aef_id"] for info in security_info]

            groups = body.split(";")
            for group in groups:
                aef_id, api_names = group.split(":")
                if aef_id not in aef_security_context:
                    current_app.logger.warning("Bad format Scope, not valid aef id ")
                    token_error = AccessTokenErr(error="invalid_scope", error_description="One of aef_id not belongs of your security context")
                    return make_response(object=clean_empty(token_error.to_dict()), status=400)

                api_names = api_names.split(",")
                for api_name in api_names:
                    service = capif_service_col.find_one(
                        {"$and": [{"api_name": api_name}, {self.filter_aef_id: aef_id}]})
                    if service is None:
                        current_app.logger.warning("Bad format Scope, not valid api name")
                        token_error = AccessTokenErr(
                            error="invalid_scope",
                            error_description="One of the api names does not exist or is not associated with the aef id provided")
                        return make_response(object=clean_empty(token_error.to_dict()), status=400)

            return None

        except Exception as e:
            current_app.logger.error("Bad format Scope: " + e)
            token_error = AccessTokenErr(error="invalid_scope", error_description="malformed scope")
            return make_response(object=clean_empty(token_error.to_dict()), status=400)
    

    def __derive_psk(self, master_key:str, session_id:str, interface:dict): 
        ## Derive the PSK using the provided master key, session ID, and interface information

        # Interface information
        if isinstance(interface, dict):
            host = None
            if 'fqdn' in interface:
                host = interface['fqdn']
            elif 'ipv4Addr' in interface:
                host = interface['ipv4Addr']
            elif 'ipv6Addr' in interface:
                host = interface['ipv6Addr']
            port = interface.get('port', None)

            api_prefix = interface.get('apiPrefix', '')
            scheme = "https" if port in (None, 443) else "http"

            interface_info = f"{scheme}://{host}"
            if port and port != 443:
                interface_info += f":{port}"
            interface_info += api_prefix
        else:
            interface_info = interface

        
        # Normalize the strings to NFKC form
        p0_string = unicodedata.normalize("NFKC", interface_info).encode("utf-8") 
        p1_string = unicodedata.normalize("NFKC", session_id).encode("utf-8") 
        
        # Convert to octet format (0xFF) 
        p0_octet_string = ' '.join(f'0x{byte:02X}' for byte in p0_string) 
        p1_octet_string = ' '.join(f'0x{byte:02X}' for byte in p1_string) 

        # Convert number of bytes to 16-bit big-endian 
        l0 = ' '.join(f'0x{byte:02X}' for byte in len(p0_octet_string).to_bytes(2, 'big')) 
        l1 = ' '.join(f'0x{byte:02X}' for byte in len(p1_octet_string).to_bytes(2, 'big')) 
        
        # Create S string using FC (0x7A) and the octet strings with their lengths 
        S = "0x7A" + ' ' + p0_octet_string + ' ' + l0 + ' ' + p1_octet_string + ' ' + l1 
        psk = hmac.new(master_key.encode("utf-8"), S.encode("utf-8"), hashlib.sha256).digest() 
        
        return psk


    def __init__(self):
        Resource.__init__(self)
        self.filter_aef_id = "aef_profiles.aef_id"

    def get_servicesecurity(self, api_invoker_id, authentication_info=True, authorization_info=True):

        mycol = self.db.get_col_by_name(self.db.security_info)

        try:

            current_app.logger.debug(
                "Obtainig security context with id: " + api_invoker_id)
            result = self.__check_invoker(api_invoker_id)
            if result != None:
                return result
            else:
                services_security_object = mycol.find_one({"api_invoker_id": api_invoker_id}, {
                                                          "_id": 0, "api_invoker_id": 0})

                if services_security_object is None:
                    current_app.logger.warning("Not found security context")
                    return not_found_error(detail=security_context_not_found_detail, cause=api_invoker_no_context_cause)

                for security_info_obj in services_security_object['security_info']:
                    if security_info_obj.get('sel_security_method') == "PKI":
                        current_app.logger.debug("PKI security method selected")
                        if authentication_info:
                            # Read the CA certificate from the file
                            with open("/usr/src/app/capif_security/ca.crt", "rb") as key_file:
                                key_data = key_file.read()
                            # Decode the certificate to a string
                            key_data = key_data.decode('utf-8')
                            # Add the CA certificate to the authentication_info
                            security_info_obj['authentication_info'] = key_data
                        else:
                            # If authentication_info is not needed, remove the key_data
                            del security_info_obj['authentication_info']

                        if authorization_info:
                            security_info_obj['authorization_info'] = security_info_obj.get('authorization_info', "")
                        else:
                            # If authorization_info is not needed, remove the key_data
                            del security_info_obj['authorization_info']

                    elif security_info_obj.get('sel_security_method') == "PSK":
                        current_app.logger.debug("PSK security method selected")
                        if authentication_info:
                            # Read the PSK from the file -> TODO
                            with open("/usr/src/app/capif_security/ca.crt", "rb") as key_file:
                                key_data = key_file.read()
                            # Decode the PSK to a string
                            key_data = key_data.decode('utf-8')
                            # Add the PSK to the authentication_info
                            security_info_obj['authentication_info'] = key_data
                        else:
                            # If authentication_info is not needed, remove the key_data
                            del security_info_obj['authentication_info']

                        if authorization_info:
                            security_info_obj['authorization_info'] = security_info_obj.get('authorization_info', "UNDER DEVELOPMENT")
                        else:
                            # If authorization_info is not needed, remove the key_data
                            del security_info_obj['authorization_info']

                    elif security_info_obj.get('sel_security_method') == "OAUTH":
                        current_app.logger.debug("OAUTH security method selected, this request is not needed")

                        if authentication_info:
                            security_info_obj['authentication_info'] = security_info_obj.get('authentication_info', "")
                        else:
                            # If authentication_info is not needed, remove the key_data
                            del security_info_obj['authentication_info']

                        if authorization_info:
                            security_info_obj['authorization_info'] = security_info_obj.get('authorization_info', "")
                        else:
                            # If authorization_info is not needed, remove the key_data
                            del security_info_obj['authorization_info']

                    else:
                        current_app.logger.warning("Bad format security method")
                        return bad_request_error(detail="Bad format security method", cause="Bad format security method", invalid_params=[{"param": "securityMethod", "reason": "Bad format security method"}])


                properyly_json = json.dumps(
                    services_security_object, default=json_util.default)
                my_service_security = dict_to_camel_case(
                    json.loads(properyly_json))
                my_service_security = clean_empty(my_service_security)

                current_app.logger.debug(
                    "Obtained security context from database")

                res = make_response(object=my_service_security, status=200)

                return res
        except Exception as e:
            exception = "An exception occurred in get security info"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def create_servicesecurity(self, api_invoker_id, service_security):
        
        mycol = self.db.get_col_by_name(self.db.security_info)

        try:

            current_app.logger.debug("Creating security context")
            result = self.__check_invoker(api_invoker_id)
            if result != None:
                return result

            if rfc3987.match(service_security.notification_destination, rule="URI") is None:
                current_app.logger.warning("Bad url format")
                return bad_request_error(detail="Bad Param", cause="Detected Bad format of param", invalid_params=[{"param": "notificationDestination", "reason": "Not valid URL format"}])

            services_security_object = mycol.find_one(
                {"api_invoker_id": api_invoker_id, "security_info.api_id": {"$in": [info.api_id for info in service_security.security_info]}}, {"_id": 0})

            if services_security_object is not None:

                current_app.logger.warning(
                    "Already security context defined with same api invoker id")
                return forbidden_error(detail="Security method already defined", cause="Identical AEF Profile IDs")

            negotiated = return_negotiated_supp_feat_dict(service_security.supported_features)
            service_security.supported_features = negotiated["Final"]

            for service_instance in service_security.security_info:

                psk_interface = None

                if service_instance.interface_details is not None:

                    # We look for if the passed interface exists for the given apiId
                    capif_service_col = self.db.get_col_by_name(
                        self.db.capif_service_col)
                    
                    aef_profiles = capif_service_col.find_one(
                        {"api_id": service_instance.api_id, 
                         "aef_profiles.interface_descriptions":{
                            "$elemMatch": service_instance.interface_details.to_dict()
                        }
                        }, 
                        {"_id": 0})
                    
                    current_app.logger.debug("Aef profile: " + str(aef_profiles))

                    if aef_profiles is None:
                        current_app.logger.warning(
                            "Not found service with this interface description: " + json.dumps(clean_empty(service_instance.interface_details.to_dict())))
                        return not_found_error(detail=f"Service with interfaceDescription {json.dumps(clean_empty(service_instance.interface_details.to_dict()))} not found", cause="Not found Service")

                    # We obtain the interface security methods
                    # We need to go deeper here, because the interface description is an array
                    # and we need to find the correct one according to preferred security method by invoker,
                    # maybe Published API contains more than one interface description, and each one is related
                    # with a different security method, then we need to get a complete list (interface and related security methods)
                    # amd then we need to check if the preferred security method is compatible with the interface description
                    # also the security methods inside interface description is not mandatory, in that case we use aefProfile.securityMethods
                    # an also that aefProfile.securityMethods is not mandatory, only in cases described on TS 29222 - 8.2.4.2.4	Type: AefProfile - 
                    # 
                    # NOTE4: 
                    # For AEFs defined by 3GPP interacting with API invokers via CAPIF-2e, at least one of the "securityMethods" attribute 
                    # within this data type or the "securityMethods" attribute within the "interfaceDescriptions" attribute shall be present. 
                    # For AEFs defined by 3GPP interacting with API invokers via CAPIF-2, the "securityMethods" attribute is optional. 
                    # For AEFs not defined by 3GPP, the "securityMethods" attribute is optional.
                    # 
                    # To achieve this, we need to setup at config which domains or IPs are CAPIF-2e or CAPIF-2, and then we need to check if the domain or IP of the service is in the list.

                    valid_security_methods = set()
                    for aefProfile in aef_profiles.get("aef_profiles", []):
                        current_app.logger.debug("AEF profile security methods: " + str(aefProfile.get("security_methods", [])))

                        profile_methods = set(aefProfile.get("security_methods") or [])
                        interfaces = aefProfile.get("interface_descriptions", [])

                        interface_methods = set()

                        if interfaces and len(interfaces) > 0:
                            for interface in interfaces:
                                # If the interface has its own security methods, use them
                                if interface == service_instance.interface_details.to_dict():
                                    if interface.get("security_methods"):
                                        interface_methods.update(interface["security_methods"])
                                    # If not, inherit the methods from the profile (if any)
                                    elif profile_methods:
                                        interface_methods.update(profile_methods)

                            # After processing all interfaces, use the combined set
                            valid_security_methods.update(interface_methods)
                        else:
                            current_app.logger.warning("No interfaces found in AEF profile.")
                            return not_found_error(detail=f"Service with interfaceDescription {json.dumps(clean_empty(service_instance.interface_details.to_dict()))} not found", cause="Not found Service")

                    psk_interface = service_instance.interface_details.to_dict()

                    current_app.logger.debug("Valid security methods: " + str(valid_security_methods))

                    pref_security_methods = service_instance.pref_security_methods
                    valid_security_method = set(
                        valid_security_methods) & set(pref_security_methods)

                else:
                    capif_service_col = self.db.get_col_by_name(
                        self.db.capif_service_col)
                    services_security_object = capif_service_col.find_one(
                        {"api_id": service_instance.api_id, self.filter_aef_id: service_instance.aef_id})
                    
                    current_app.logger.debug("Aef profile: " + str(services_security_object))
                    if services_security_object is None:
                        current_app.logger.warning(
                            "Not found service with this aef id: " + service_instance.aef_id)
                        return not_found_error(detail="Service with this aefId not found", cause="Not found Service")
                    
                    # We obtain all the security methods available for the given aef_id
                    valid_security_methods = set()
                    for aefProfile in services_security_object.get("aef_profiles", []):
                        current_app.logger.debug("AEF profile security methods: " + str(aefProfile.get("security_methods", [])))

                        profile_methods = set(aefProfile.get("security_methods") or [])
                        interfaces = aefProfile.get("interface_descriptions", [])

                        interface_methods = set()

                        current_app.logger.debug(f"Interfaces: {interfaces}, Profile Methods: {profile_methods}")
                        if interfaces and len(interfaces) > 0:
                            for interface in interfaces:
                                # If the interface has its own security methods, use them
                                if interface.get("security_methods"):
                                    interface_methods.update(interface["security_methods"])
                                # If not, inherit the methods from the profile (if any)
                                elif profile_methods:
                                    interface_methods.update(profile_methods)
                                else:
                                    current_app.logger.debug("Interface has no security methods and profile has none to inherit.")

                                # Keep track if any interface supports PSK
                                if psk_interface is None and "PSK" in interface_methods:
                                    psk_interface = interface

                            # After processing all interfaces, use the combined set
                            valid_security_methods.update(interface_methods)
                        else:
                            # No interfaces: use the profile's security methods directly
                            if profile_methods:
                                valid_security_methods.update(profile_methods)

                                # Keep track if profile supports PSK
                                if psk_interface is None and "PSK" in profile_methods:
                                    psk_interface = aefProfile.get("domain_name")

                            else:
                                current_app.logger.debug("AEF profile has no security methods defined (no interfaces either).")

                    current_app.logger.debug("Valid security methods: " + str(valid_security_methods))

                    # We intersect with preferred security methods
                    pref_security_methods = service_instance.pref_security_methods
                    valid_security_method = set(
                        valid_security_methods) & set(pref_security_methods)

                if len(list(valid_security_method)) == 0:
                    current_app.logger.warning(
                        "Not found comptaible security method with pref security method")
                    return bad_request_error(detail="Not found compatible security method with pref security method", cause="Error pref security method", invalid_params=[{"param": "prefSecurityMethods", "reason": "pref security method not compatible with security method available"}])

                # Retrieve security method priority configuration from the database
                config_col = self.db.get_col_by_name("capif_configuration")
                capif_config = config_col.find_one({"config_name": "default"})
                if not capif_config:
                    current_app.logger.error("CAPIF Configuration not found when trying to retrieve security method priority")
                    return internal_server_error(detail="CAPIF Configuration not found when trying to retrieve security method priority", cause="Database Error")

                priority_mapping = capif_config["settings"]["security_method_priority"]

                # Sort valid security methods based on priority from the configuration
                sorted_methods = sorted(valid_security_method, key=lambda method: priority_mapping.get(method.lower(), float('inf')))

                # Select the highest-priority security method
                service_instance.sel_security_method = sorted_methods[0]

                if service_instance.sel_security_method == "PSK":
                    tls_protocol = request.headers.get('X-TLS-Protocol', 'N/A')
                    session_id = request.headers.get('X-TLS-Session-ID', 'N/A')  
                    mkey = request.headers.get('X-TLS-MKey', 'N/A') 
                    current_app.logger.debug(f"TLS Protocol: {tls_protocol}, Session id: {session_id}, Master Key: {mkey}") 

                    if psk_interface:
                        current_app.logger.debug("Deriving PSK")
                        psk = self.__derive_psk(mkey, session_id, psk_interface)
                        current_app.logger.debug("PSK derived : " + str(psk))

                        service_instance.authorization_info = str(psk)
                    else:
                        current_app.logger.warning("No interface information available to derive PSK")
                        
                # Send service instance to ACL
                current_app.logger.debug("Sending message to create ACL")
                publish_ops.publish_message("acls-messages", "create-acl:"+str(
                    api_invoker_id)+":"+str(service_instance.api_id)+":"+str(service_instance.aef_id))
                current_app.logger.info(
                    "Inserted security context in database")

            # We use update with $setOnInsert and $push with $each to add the security info array if the document is created
            on_insert = service_security.to_dict().copy()
            on_insert.pop('security_info', None) 

            security_context = mycol.find_one_and_update({'api_invoker_id': api_invoker_id},
                             {"$setOnInsert": on_insert,
                              "$push": {"security_info": {"$each": [sec.to_dict() for sec in service_security.security_info]}}},
                             upsert=True ,
                             return_document=ReturnDocument.AFTER,
                             projection={'_id': 0, 'api_invoker_id': 0}   
                             )

            res = make_response(object=serialize_clean_camel_case(service_security), status=201)
            res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/capif-security/v1/trustedInvokers/{str(api_invoker_id)}"

            return res

        except Exception as e:
            exception = "An exception occurred in create security info"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def delete_servicesecurity(self, api_invoker_id):

        mycol = self.db.get_col_by_name(self.db.security_info)

        try:

            current_app.logger.debug("Removing security context")

            result = self.__check_invoker(api_invoker_id)
            if result != None:
                return result
            else:
                my_query = {'api_invoker_id': api_invoker_id}
                services_security_count = mycol.count_documents(my_query)

                if services_security_count == 0:
                    current_app.logger.warning(security_context_not_found_detail)
                    return not_found_error(detail=security_context_not_found_detail, cause=api_invoker_no_context_cause)

                mycol.delete_many(my_query)

                publish_ops.publish_message(
                    "acls-messages", "remove-acl:"+api_invoker_id)

                current_app.logger.info(
                    "Removed security context from database")
                out = "The security info of Network App with Network App ID " + \
                    api_invoker_id + " were deleted.", 204
                return make_response(out, status=204)

        except Exception as e:
            exception = "An exception occurred in create security info"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def delete_intern_servicesecurity(self, api_invoker_id):

        mycol = self.db.get_col_by_name(self.db.security_info)
        my_query = {'api_invoker_id': api_invoker_id}
        mycol.delete_many(my_query)

    def return_token(self, security_id, access_token_req):

        mycol = self.db.get_col_by_name(self.db.security_info)

        try:

            current_app.logger.debug("Generating access token")

            invokers_col = self.db.get_col_by_name(self.db.capif_invokers)

            current_app.logger.debug(
                "Checking api invoker with id: " + access_token_req["client_id"])
            invoker = invokers_col.find_one(
                {"api_invoker_id": access_token_req["client_id"]})
            if invoker is None:
                client_id_error = AccessTokenErr(error="invalid_client", error_description="Client Id not found")
                return make_response(object=clean_empty(client_id_error.to_dict()), status=400)

            if access_token_req["grant_type"] != "client_credentials":
                client_id_error = AccessTokenErr(error="unsupported_grant_type",
                                                 error_description="Invalid value for `grant_type` ({0}), must be one of ['client_credentials'] - 'grant_type'"
                                                 .format(access_token_req["grant_type"]))
                return make_response(object=clean_empty(client_id_error.to_dict()), status=400)

            service_security = mycol.find_one({"api_invoker_id": security_id})
            if service_security is None:
                current_app.logger.warning("Not found security context with id: " + security_id)
                return not_found_error(detail= security_context_not_found_detail, cause=api_invoker_no_context_cause)

            result = self.__check_scope(
                access_token_req["scope"], service_security)

            if result != None:
                return result

            expire_time = timedelta(minutes=10)
            now = datetime.now()

            claims = AccessTokenClaims(iss=access_token_req["client_id"], scope=access_token_req["scope"], exp=int(
                (now+expire_time).timestamp()))
            access_token = create_access_token(
                identity=access_token_req["client_id"], additional_claims=claims.to_dict())
            access_token_resp = AccessTokenRsp(access_token=access_token, token_type="Bearer", expires_in=int(
                expire_time.total_seconds()), scope=access_token_req["scope"])

            current_app.logger.info("Created access token")

            res = make_response(object=clean_empty(access_token_resp.to_dict()), status=200)
            return res
        except Exception as e:
            exception = "An exception occurred in return token"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def update_servicesecurity(self, api_invoker_id, service_security):
        mycol = self.db.get_col_by_name(self.db.security_info)
        try:

            negotiated_supported_features = return_negotiated_supp_feat_dict(service_security.supported_features)
            service_security.supported_features = negotiated_supported_features["Final"]

            current_app.logger.debug("Updating security context")
            result = self.__check_invoker(api_invoker_id)
            if result != None:
                return result

            old_object = mycol.find_one({"api_invoker_id": api_invoker_id})

            if old_object is None:
                current_app.logger.warning(
                    "Service api not found with id: " + api_invoker_id)
                return not_found_error(detail="Service API not existing", cause="Not exist securiy information for this invoker")

            update_acls=list()
            for service_instance in service_security.security_info:

                psk_interface = None

                if service_instance.interface_details is not None:

                     # We look for if the passed interface exists for the given apiId
                    capif_service_col = self.db.get_col_by_name(
                        self.db.capif_service_col)
                    
                    aef_profiles = capif_service_col.find_one(
                        {"api_id": service_instance.api_id, 
                         "aef_profiles.interface_descriptions":{
                            "$elemMatch": service_instance.interface_details.to_dict()
                        }
                        }, 
                        {"_id": 0})
                    
                    current_app.logger.debug("Aef profile: " + str(aef_profile))

                    if aef_profiles is None:
                        current_app.logger.warning(
                            "Not found service with this interface description: " + json.dumps(clean_empty(service_instance.interface_details.to_dict())))
                        return not_found_error(detail=f"Service with interfaceDescription {json.dumps(clean_empty(service_instance.interface_details.to_dict()))} not found", cause="Not found Service")


                    valid_security_methods = set()
                    for aefProfile in aef_profiles.get("aef_profiles", []):
                        current_app.logger.debug("AEF profile security methods: " + str(aefProfile.get("security_methods", [])))

                        profile_methods = set(aefProfile.get("security_methods") or [])
                        interfaces = aefProfile.get("interface_descriptions", [])

                        interface_methods = set()

                        if interfaces and len(interfaces) > 0:
                            for interface in interfaces:
                                # If the interface has its own security methods, use them
                                if interface == service_instance.interface_details.to_dict():
                                    if interface.get("security_methods"):
                                        interface_methods.update(interface["security_methods"])
                                    # If not, inherit the methods from the profile (if any)
                                    elif profile_methods:
                                        interface_methods.update(profile_methods)

                            # After processing all interfaces, use the combined set
                            valid_security_methods.update(interface_methods)
                        else:
                            current_app.logger.warning("No interfaces found in AEF profile.")
                            return not_found_error(detail=f"Service with interfaceDescription {json.dumps(clean_empty(service_instance.interface_details.to_dict()))} not found", cause="Not found Service")

                    psk_interface = service_instance.interface_details.to_dict()

                    current_app.logger.debug("Valid security methods: " + str(valid_security_methods))

                    pref_security_methods = service_instance.pref_security_methods
                    valid_security_method = set(
                        valid_security_methods) & set(pref_security_methods)

                else:

                
                    capif_service_col = self.db.get_col_by_name(
                        self.db.capif_service_col)
                    services_security_object = capif_service_col.find_one(
                        {"api_id": service_instance.api_id, self.filter_aef_id: service_instance.aef_id})
                    
                    current_app.logger.debug("Aef profile: " + str(services_security_object))
                    if services_security_object is None:
                        current_app.logger.warning(
                            "Not found service with this aef id: " + service_instance.aef_id)
                        return not_found_error(detail="Service with this aefId not found", cause="Not found Service")
                    
                    # We obtain all the security methods available for the given aef_id
                    valid_security_methods = set()
                    for aefProfile in services_security_object.get("aef_profiles", []):
                        current_app.logger.debug("AEF profile security methods: " + str(aefProfile.get("security_methods", [])))

                        profile_methods = set(aefProfile.get("security_methods") or [])
                        interfaces = aefProfile.get("interface_descriptions", [])

                        interface_methods = set()

                        current_app.logger.debug(f"Interfaces: {interfaces}, Profile Methods: {profile_methods}")
                        if interfaces and len(interfaces) > 0:
                            for interface in interfaces:
                                # If the interface has its own security methods, use them
                                if interface.get("security_methods"):
                                    interface_methods.update(interface["security_methods"])
                                # If not, inherit the methods from the profile (if any)
                                elif profile_methods:
                                    interface_methods.update(profile_methods)
                                else:
                                    current_app.logger.debug("Interface has no security methods and profile has none to inherit.")

                                # Keep track if any interface supports PSK
                                if psk_interface is None and "PSK" in interface_methods:
                                    psk_interface = interface

                            # After processing all interfaces, use the combined set
                            valid_security_methods.update(interface_methods)
                        else:
                            # No interfaces: use the profile's security methods directly
                            if profile_methods:
                                valid_security_methods.update(profile_methods)

                                # Keep track if profile supports PSK
                                if psk_interface is None and "PSK" in profile_methods:
                                    psk_interface = aefProfile.get("domain_name")

                            else:
                                current_app.logger.debug("AEF profile has no security methods defined (no interfaces either).")

                    current_app.logger.debug("Valid security methods: " + str(valid_security_methods))

                    # We intersect with preferred security methods
                    pref_security_methods = service_instance.pref_security_methods
                    valid_security_method = set(
                        valid_security_methods) & set(pref_security_methods)
                    
                if len(list(valid_security_method)) == 0:
                    current_app.logger.warning(
                        "Not found comptaible security method with pref security method")
                    return bad_request_error(detail="Not found compatible security method with pref security method", cause="Error pref security method", invalid_params=[{"param": "prefSecurityMethods", "reason": "pref security method not compatible with security method available"}])
                
                service_instance.sel_security_method = list(
                        valid_security_method)[0]
                update_acls.append({"api_id": service_instance.api_id, "aef_id": service_instance.aef_id})

                if service_instance.sel_security_method == "PSK":
                    tls_protocol = request.headers.get('X-TLS-Protocol', 'N/A')
                    session_id = request.headers.get('X-TLS-Session-ID', 'N/A')  
                    mkey = request.headers.get('X-TLS-MKey', 'N/A') 
                    current_app.logger.debug(f"TLS Protocol: {tls_protocol}, Session id: {session_id}, Master Key: {mkey}") 

                    if psk_interface:
                        current_app.logger.debug("Deriving PSK")
                        psk = self.__derive_psk(mkey, session_id, psk_interface)
                        current_app.logger.debug("PSK derived : " + str(psk))

                        service_instance.authorization_info = str(psk)
                    else:
                        current_app.logger.warning("No interface information available to derive PSK")

            service_security = service_security.to_dict()
            service_security = clean_empty(service_security)

            result = mycol.find_one_and_update(old_object, {"$set": service_security}, projection={
                                               '_id': 0, "api_invoker_id": 0}, return_document=ReturnDocument.AFTER, upsert=False)
            current_app.logger.info(
                    "Inserted security context in database")

            # result = clean_empty(result)
            for update_acl in update_acls:
                # Send service instance to ACL
                current_app.logger.debug("Sending message to create ACL")
                publish_ops.publish_message("acls-messages", "create-acl:"+str(
                    api_invoker_id)+":"+str(update_acl['api_id'])+":"+str(update_acl['aef_id']))

            current_app.logger.info("Updated security context")

            res= make_response(object=dict_to_camel_case(clean_empty(result)), status=200)
            res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/capif-security/v1/trustedInvokers/{str(api_invoker_id)}"

            return res
        except Exception as e:
            exception = "An exception occurred in update security info"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def revoke_api_authorization(self, api_invoker_id, security_notification):

        mycol = self.db.get_col_by_name(self.db.security_info)

        try:

            current_app.logger.debug("Revoking security context")
            result = self.__check_invoker(api_invoker_id)
            if result != None:
                return result

            my_query = {'api_invoker_id': api_invoker_id}
            services_security_context = mycol.find_one(my_query)

            if services_security_context is None:
                current_app.logger.warning(security_context_not_found_detail)
                return not_found_error(detail=security_context_not_found_detail, cause=api_invoker_no_context_cause)

            updated_security_context = services_security_context.copy()
            for context in services_security_context["security_info"]:
                index = services_security_context["security_info"].index(
                    context)
                if security_notification.aef_id == context["aef_id"] or context["api_id"] in security_notification.api_ids:
                    current_app.logger.debug("Sending message.")
                    publish_ops.publish_message("acls-messages", "remove-acl:"+str(
                        api_invoker_id)+":"+str(context["api_id"])+":"+str(security_notification.aef_id))
                    current_app.logger.debug("message sended.")
                    updated_security_context["security_info"].pop(index)

            mycol.replace_one(my_query, updated_security_context)

            if len(updated_security_context["security_info"]) == 0:
                mycol.delete_many(my_query)

            current_app.logger.debug("Revoked security context")
            out = "Netapp with ID " + api_invoker_id + " was revoked by some APIs.", 204
            res = make_response(out, status=204)
            if res.status_code == 204:
                current_app.logger.info("Permissions revoked")
                RedisEvent("API_INVOKER_AUTHORIZATION_REVOKED").send_event()

            return res

        except Exception as e:
            exception = "An exception occurred in revoke security auth"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
