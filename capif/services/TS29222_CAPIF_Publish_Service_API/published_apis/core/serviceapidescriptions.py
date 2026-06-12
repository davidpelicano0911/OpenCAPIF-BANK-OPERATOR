import os
import secrets
from datetime import datetime

from flask import current_app
from pymongo import ReturnDocument

from ..models.service_api_description import ServiceAPIDescription
from ..util import clean_empty, clean_n_camel_case, dict_to_camel_case
from ..vendor_specific import add_vend_spec_fields
from .auth_manager import AuthManager
from .publisher import Publisher
from .redis_event import RedisEvent
from .resources import Resource
from .responses import (bad_request_error, forbidden_error,
                        internal_server_error, make_response, not_found_error,
                        unauthorized_error)

TOTAL_FEATURES = 10
SUPPORTED_FEATURES_HEX = "120"

publisher_ops = Publisher()


service_api_not_found_message = "Service API not found"

def find_duplicate_service_by_api_name_and_aef(
        collection,
        api_name,
        aef_profiles,
        excluded_api_id=None):
    duplicate_query = {"api_name": api_name}
    aef_ids = set()
    for profile in aef_profiles or []:
        if isinstance(profile, dict):
            aef_id = profile.get("aef_id")
        else:
            aef_id = getattr(profile, "aef_id", None)

        if aef_id:
            aef_ids.add(aef_id)

    aef_ids = sorted(aef_ids)

    if aef_ids:
        duplicate_query["aef_profiles.aef_id"] = {"$in": aef_ids}
    if excluded_api_id:
        duplicate_query["api_id"] = {"$ne": excluded_api_id}

    return collection.find_one(duplicate_query), aef_ids


def return_negotiated_supp_feat_dict(supp_feat):
    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "ApiSupportedFeaturePublishing": True if final_supp_feat[0] == "1" else False,
        "PatchUpdate": True if final_supp_feat[1] == "1" else False,
        "ExtendedIntfDesc": True if final_supp_feat[2] == "1" else False,
        "MultipleCustomOperations": True if final_supp_feat[3] == "1" else False,
        "ProtocDataFormats_Ext1": True if final_supp_feat[4] == "1" else False,
        "ApiStatusMonitoring": True if final_supp_feat[5] == "1" else False,
        "EdgeApp_2": True if final_supp_feat[6] == "1" else False,
        "RNAA": True if final_supp_feat[7] == "1" else False,
        "VendorExt": True if final_supp_feat[8] == "1" else False,
        "SliceBasedAPIExposure": True if final_supp_feat[9] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:].zfill(3)
    }

class PublishServiceOperations(Resource):

    def check_apf(self, apf_id):
        providers_col = self.db.get_col_by_name(self.db.capif_provider_col)

        current_app.logger.debug("Checking apf id")
        provider = providers_col.find_one(
            {"api_prov_funcs.api_prov_func_id": apf_id})

        if provider is None:
            current_app.logger.warning("Publisher not exist")
            return unauthorized_error(
                detail="Publisher not existing",
                cause="Publisher id not found")

        list_apf_ids = [func["api_prov_func_id"]
                        for func in provider["api_prov_funcs"] if func["api_prov_func_role"] == "APF"]
        if apf_id not in list_apf_ids:
            current_app.logger.warning("This id not belongs to APF")
            return unauthorized_error(
                detail="You are not a publisher",
                cause="This API is only available for publishers")

        return None

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()

    def get_serviceapis(self, apf_id):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:

            current_app.logger.debug("Geting service apis")

            service = mycol.find(
                {"apf_id": apf_id},
                {"_id": 0,
                 "api_name": 1,
                 "api_id": 1,
                 "aef_profiles": 1,
                 "description": 1,
                 "supported_features": 1,
                 "shareable_info": 1,
                 "service_api_category": 1,
                 "api_supp_feats": 1,
                 "pub_api_path": 1,
                 "ccf_id": 1,
                 "api_status": 1})
            current_app.logger.debug(service)
            if service is None:
                current_app.logger.warning("Not found services for this apf id")
                return not_found_error(detail="Not exist published services for this apf_id", cause="Not exist service with this apf_id")

            json_docs = []
            for serviceapi in service:
                my_service_api = dict_to_camel_case(serviceapi)
                my_service_api = clean_empty(my_service_api)
                json_docs.append(my_service_api)

            current_app.logger.debug("Obtained services apis")
            current_app.logger.debug(json_docs)

            res = make_response(object=json_docs, status=200)
            return res

        except Exception as e:
            exception = "An exception occurred in get services"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def add_serviceapidescription(self, apf_id, serviceapidescription, vendor_specific):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:
            current_app.logger.debug("Publishing service")

            serviceapidescription_dict = serviceapidescription.to_dict()
            service, aef_ids = find_duplicate_service_by_api_name_and_aef(
                mycol,
                serviceapidescription.api_name,
                serviceapidescription_dict.get("aef_profiles"))
            if service is not None:
                if aef_ids:
                    current_app.logger.warning(
                        "Service already registered with same api_name/aef_id pair")
                    return forbidden_error(
                        detail="Already registered service with same api name and aef id",
                        cause="Found service with same api name and aef id")

                current_app.logger.warning(
                    "Service already registered with same api name")
                return forbidden_error(
                    detail="Already registered service with same api name",
                    cause="Found service with same api name")

            api_id = secrets.token_hex(15)
            serviceapidescription.api_id = api_id
            serviceapidescription_dict["api_id"] = api_id
            rec = dict()
            rec['apf_id'] = apf_id
            rec['onboarding_date'] = datetime.now()

            if vendor_specific:
                serviceapidescription_dict = add_vend_spec_fields(
                    vendor_specific, serviceapidescription_dict)

            rec.update(serviceapidescription_dict)
            if not return_negotiated_supp_feat_dict(rec.get("supported_features"))["ApiStatusMonitoring"] and rec.get("api_status", None) is not None:
                return bad_request_error(
                    detail="Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed",
                    cause="apiStatus can't be set if apiStatusMonitoring is inactive",
                    invalid_params=[{"param": "apiStatus", "reason": "defined but apiStatusMoniroting feature not active"}]
                )
            mycol.insert_one(rec)

            self.auth_manager.add_auth_service(api_id, apf_id)

            current_app.logger.debug("Service inserted in database")

            res = make_response(object=clean_n_camel_case(
                serviceapidescription_dict), status=201)
            res.headers['Location'] = f"https://{os.getenv('CAPIF_HOSTNAME')}/published-apis/v1/{str(apf_id)}/service-apis/{str(api_id)}"

            if res.status_code == 201:
                current_app.logger.info("Service published")
                event_to_send = self.service_api_availability_event(
                    clean_n_camel_case(
                        serviceapidescription_dict))
                RedisEvent(event_to_send,
                           service_api_descriptions=[clean_n_camel_case(
                               serviceapidescription.to_dict())],
                           api_ids=[str(api_id)]).send_event()

            return res

        except Exception as e:
            exception = "An exception occurred in add services"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def get_one_serviceapi(self, service_api_id, apf_id):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:
            current_app.logger.debug(
                "Geting service api with id: " + service_api_id)

            my_query = {'apf_id': apf_id, 'api_id': service_api_id}
            service_api = mycol.find_one(my_query, {"_id": 0,
                                                    "api_name": 1,
                                                    "api_id": 1,
                                                    "aef_profiles": 1,
                                                    "description": 1,
                                                    "supported_features": 1,
                                                    "shareable_info": 1,
                                                    "service_api_category": 1,
                                                    "api_supp_feats": 1,
                                                    "pub_api_path": 1,
                                                    "ccf_id": 1,
                                                    "api_status": 1})
            if service_api is None:
                current_app.logger.warning(service_api_not_found_message)
                return not_found_error(
                    detail=service_api_not_found_message,
                    cause="No Service with specific credentials exists")

            my_service_api = dict_to_camel_case(service_api)
            my_service_api = clean_empty(my_service_api)

            current_app.logger.debug("Obtained service api")
            res = make_response(object=my_service_api, status=200)
            return res

        except Exception as e:
            exception = "An exception occurred in get one service"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def delete_serviceapidescription(self, service_api_id, apf_id):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:

            current_app.logger.debug(
                "Removing api service with id: " + service_api_id)

            my_query = {'apf_id': apf_id, 'api_id': service_api_id}
            serviceapidescription_dict = mycol.find_one(my_query, {"_id": 0,
                                                                  "api_name": 1,
                                                                  "api_id": 1,
                                                                  "aef_profiles": 1,
                                                                  "description": 1,
                                                                  "supported_features": 1,
                                                                  "shareable_info": 1,
                                                                  "service_api_category": 1,
                                                                  "api_supp_feats": 1,
                                                                  "pub_api_path": 1,
                                                                  "ccf_id": 1,
                                                                  "api_status": 1})

            if serviceapidescription_dict is None:
                current_app.logger.warning(service_api_not_found_message)
                return not_found_error(
                    detail="Service API not existing",
                    cause="Service API id not found")

            mycol.delete_one(my_query)

            self.auth_manager.remove_auth_service(service_api_id, apf_id)

            current_app.logger.info("Removed service from database")
            out = "The service matching api_id " + service_api_id + " was deleted."
            res = make_response(out, status=204)
            serviceapidescription = clean_empty(
                dict_to_camel_case(serviceapidescription_dict))
            if res.status_code == 204:
                current_app.logger.debug("Checking if SERVICE_API_UNAVAILABLE event must be notified")
                event_to_send = self.service_api_availability_event(
                    clean_n_camel_case(
                        serviceapidescription_dict))
                if event_to_send != "SERVICE_API_UNAVAILABLE":
                    current_app.logger.debug("Send SERVICE_API_UNAVAILABLE event")
                    RedisEvent(
                        "SERVICE_API_UNAVAILABLE",
                        service_api_descriptions=[serviceapidescription],
                        api_ids=[str(service_api_id)]
                    ).send_event()
                else:
                    current_app.logger.debug("Not send SERVICE_API_UNAVAILABLE because this Service API was unavailable previously")

            return res

        except Exception as e:
            exception = "An exception occurred in delete service"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def update_serviceapidescription(self,
                                     service_api_id, apf_id,
                                     service_api_description):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:

            current_app.logger.debug(
                "Updating service api with id: " + service_api_id)

            my_query = {'apf_id': apf_id, 'api_id': service_api_id}
            serviceapidescription_old = mycol.find_one(my_query, {"_id": 0,
                                                                  "api_name": 1,
                                                                  "api_id": 1,
                                                                  "aef_profiles": 1,
                                                                  "description": 1,
                                                                  "supported_features": 1,
                                                                  "shareable_info": 1,
                                                                  "service_api_category": 1,
                                                                  "api_supp_feats": 1,
                                                                  "pub_api_path": 1,
                                                                  "ccf_id": 1,
                                                                  "apf_id":1,
                                                                  "onboarding_date": 1,
                                                                  "api_status": 1})
            if serviceapidescription_old is None:
                current_app.logger.warning(service_api_not_found_message)
                return not_found_error(detail="Service API not existing", cause="Service API id not found")

            service_api_description = service_api_description.to_dict()
            api_status = service_api_description.get("api_status", None)
            service_api_description = clean_empty(service_api_description)
            if api_status:
                service_api_description["api_status"]=api_status
            service_api_description["apf_id"] = serviceapidescription_old["apf_id"]
            service_api_description["onboarding_date"] = serviceapidescription_old["onboarding_date"]
            service_api_description["api_id"] = serviceapidescription_old["api_id"]

            service_with_same_identity, aef_ids = find_duplicate_service_by_api_name_and_aef(
                mycol,
                service_api_description.get("api_name", serviceapidescription_old.get("api_name")),
                service_api_description.get("aef_profiles", serviceapidescription_old.get("aef_profiles")),
                excluded_api_id=service_api_description["api_id"])
            if service_with_same_identity is not None:
                if aef_ids:
                    current_app.logger.error(
                        "Service already registered with same api_name/aef_id pair")
                    return forbidden_error(
                        detail="Already registered service with same api name and aef id",
                        cause="Found service with same api name and aef id")

                current_app.logger.error(
                    "Service already registered with same api name")
                return forbidden_error(
                    detail="Already registered service with same api name",
                    cause="Found service with same api name")

            service_api_description["supported_features"] = return_negotiated_supp_feat_dict(service_api_description["supported_features"])["Final"]

            if not return_negotiated_supp_feat_dict(service_api_description.get("supported_features"))["ApiStatusMonitoring"] and service_api_description.get("api_status", None) is not None:
                return bad_request_error(
                    detail="Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed",
                    cause="apiStatus can't be set if apiStatusMonitoring is inactive",
                    invalid_params=[{"param": "apiStatus", "reason": "defined but apiStatusMoniroting feature not active"}]
                )

            result = mycol.find_one_and_replace(
                serviceapidescription_old,
                service_api_description,
                projection={"_id": 0,
                            "api_name": 1,
                            "api_id": 1,
                            "aef_profiles": 1,
                            "description": 1,
                            "supported_features": 1,
                            "shareable_info": 1,
                            "service_api_category": 1,
                            "api_supp_feats": 1,
                            "pub_api_path": 1,
                            "ccf_id": 1,
                            "api_status": 1},
                return_document=ReturnDocument.AFTER, upsert=False)

            result = clean_empty(result)
            current_app.logger.info("Updated service api")

            service_api_description_updated = dict_to_camel_case(result)

            response = make_response(
                object=service_api_description_updated, status=200)

            if response.status_code == 200:
                RedisEvent("SERVICE_API_UPDATE",
                           service_api_descriptions=[service_api_description_updated]).send_event()

                my_service_api = clean_empty(serviceapidescription_old)

                if (api_status := serviceapidescription_old.get("api_status")):
                    my_service_api["api_status"] = api_status
                
                my_service_api = dict_to_camel_case(my_service_api)
                
                self.send_events_on_update(
                    service_api_id,
                    my_service_api,
                    service_api_description_updated)

            return response

        except Exception as e:
            exception = "An exception occurred in update service"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def patch_serviceapidescription(self,
                                     service_api_id, apf_id,
                                     patch_service_api_description):

        mycol = self.db.get_col_by_name(self.db.service_api_descriptions)

        try:

            current_app.logger.debug(
                "Patching service api with id: " + service_api_id)

            my_query = {'apf_id': apf_id, 'api_id': service_api_id}
            serviceapidescription_old = mycol.find_one(my_query, {"_id": 0,
                                                                  "api_name": 1,
                                                                  "api_id": 1,
                                                                  "aef_profiles": 1,
                                                                  "description": 1,
                                                                  "supported_features": 1,
                                                                  "shareable_info": 1,
                                                                  "service_api_category": 1,
                                                                  "api_supp_feats": 1,
                                                                  "pub_api_path": 1,
                                                                  "ccf_id": 1,
                                                                  "api_status": 1})
            if serviceapidescription_old is None:
                current_app.logger.warning(service_api_not_found_message)
                return not_found_error(detail="Service API not existing", cause="Service API id not found")

            patch_service_api_description = patch_service_api_description.to_dict()
            api_status = patch_service_api_description.get("api_status", None)
            supported_features = patch_service_api_description.get("supported_features", None)
            patch_service_api_description = clean_empty(patch_service_api_description)

            service_with_same_identity, aef_ids = find_duplicate_service_by_api_name_and_aef(
                mycol,
                serviceapidescription_old.get("api_name"),
                patch_service_api_description.get("aef_profiles", serviceapidescription_old.get("aef_profiles")),
                excluded_api_id=serviceapidescription_old.get("api_id"))
            if service_with_same_identity is not None:
                if aef_ids:
                    current_app.logger.error(
                        "Service already registered with same api_name/aef_id pair")
                    return forbidden_error(
                        detail="Already registered service with same api name and aef id",
                        cause="Found service with same api name and aef id")

                current_app.logger.error(
                    "Service already registered with same api name")
                return forbidden_error(
                    detail="Already registered service with same api name",
                    cause="Found service with same api name")

            if api_status:
                patch_service_api_description["api_status"]=api_status
            if supported_features:
                patch_service_api_description["supported_features"] = return_negotiated_supp_feat_dict(patch_service_api_description["supported_features"])["Final"]
            
            if not return_negotiated_supp_feat_dict(serviceapidescription_old.get("supported_features"))["ApiStatusMonitoring"] and patch_service_api_description.get("api_status", None) is not None:
                return bad_request_error(
                    detail="Set apiStatus with apiStatusMonitoring feature inactive at supportedFeatures if not allowed",
                    cause="apiStatus can't be set if apiStatusMonitoring is inactive",
                    invalid_params=[{"param": "apiStatus", "reason": "defined but apiStatusMoniroting feature not active"}]
                )

            result = mycol.find_one_and_update(
                my_query,
                {"$set": patch_service_api_description},
                projection={"_id": 0,
                            "api_name": 1,
                            "api_id": 1,
                            "aef_profiles": 1,
                            "description": 1,
                            "supported_features": 1,
                            "shareable_info": 1,
                            "service_api_category": 1,
                            "api_supp_feats": 1,
                            "pub_api_path": 1,
                            "ccf_id": 1,
                            "api_status": 1},
                return_document=ReturnDocument.AFTER, upsert=False)

            result = clean_empty(result)

            current_app.logger.info("Patched service api")

            service_api_description_updated = dict_to_camel_case(result)

            response = make_response(
                object=service_api_description_updated, status=200)

            if response.status_code == 200:
                RedisEvent("SERVICE_API_UPDATE",
                           service_api_descriptions=[service_api_description_updated]).send_event()

                my_service_api = clean_empty(serviceapidescription_old)

                if (api_status := serviceapidescription_old.get("api_status")):
                    my_service_api["api_status"] = api_status
                
                my_service_api = dict_to_camel_case(my_service_api)

                self.send_events_on_update(
                    service_api_id,
                    my_service_api,
                    service_api_description_updated)

            return response

        except Exception as e:
            exception = "An exception occurred in update service"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))


    def send_events_on_update(self,
                              service_api_id,
                              service_api_description_old,
                              service_api_description_new):
        current_app.logger.debug("Send Events if needed")
        service_api_status_event_old = self.service_api_availability_event(
            service_api_description_old)
        current_app.logger.debug("Service API status before update is " + service_api_status_event_old)
        service_api_status_event_new = self.service_api_availability_event(
            service_api_description_new)
        current_app.logger.debug("Service API status after update is " + service_api_status_event_new)

        if service_api_status_event_old == service_api_status_event_new:
            current_app.logger.info(
                "service_api_status not changed, it remains " +
                service_api_status_event_new +
                " Then no event will be sent")
        else:
            current_app.logger.info("service_api_status changed, event " +
                                    service_api_status_event_new +
                                    " Event will be sent")
            RedisEvent(service_api_status_event_new,
                       service_api_descriptions=[
                           service_api_description_new],
                       api_ids=[str(service_api_id)]).send_event()

    def service_api_availability_event(self, service_api_description):
        service_api_status = ""
        if return_negotiated_supp_feat_dict(service_api_description.get("supportedFeatures"))["ApiStatusMonitoring"]:
            current_app.logger.debug(
                "ApiStatusMonitoring active")
            if service_api_description.get("apiStatus") is None or len(service_api_description.get("apiStatus").get("aefIds")) > 0:
                current_app.logger.debug(
                    "Service available, at least one AEF is available")
                service_api_status = "SERVICE_API_AVAILABLE"
            else:
                current_app.logger.debug(
                    "Service unavailable, all AEFs are unavailable")
                service_api_status = "SERVICE_API_UNAVAILABLE"
        else:
            current_app.logger.debug("ApiStatusMonitoring")
            current_app.logger.debug("Service available")
            service_api_status = "SERVICE_API_AVAILABLE"
        return service_api_status
