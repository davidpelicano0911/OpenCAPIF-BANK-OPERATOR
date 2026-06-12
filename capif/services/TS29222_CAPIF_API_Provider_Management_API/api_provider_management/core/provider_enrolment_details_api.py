
import os
import secrets
from datetime import datetime

from api_provider_management.models.api_provider_enrolment_details import \
    APIProviderEnrolmentDetails  # noqa: E501
from flask import Response, current_app
from pymongo import ReturnDocument

from ..core.sign_certificate import sign_certificate
from ..util import clean_empty, dict_to_camel_case, serialize_clean_camel_case
from .auth_manager import AuthManager
from .redis_internal_event import RedisInternalEvent
from .resources import Resource
from .responses import (bad_request_error, forbidden_error,
                        internal_server_error, make_response, not_found_error)

TOTAL_FEATURES = 2
SUPPORTED_FEATURES_HEX = "0"

def return_negotiated_supp_feat_dict(supp_feat):
    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]
    return {
        "PatchUpdate": True if final_supp_feat[0] == "1" else False,
        "RNAA": True if final_supp_feat[1] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }

class ProviderManagementOperations(Resource):

    def __check_api_provider_domain(self, api_prov_dom_id):
        mycol = self.db.get_col_by_name(self.db.provider_enrolment_details)

        current_app.logger.debug("Checking api provider domain id")
        search_filter = {'api_prov_dom_id': api_prov_dom_id}
        provider_enrolment_details = mycol.find_one(search_filter)

        if provider_enrolment_details is None:
            current_app.logger.warning("Not found api provider domain")
            return not_found_error(detail="Not Exist Provider Enrolment Details", cause="Not found registrations to send this api provider details")

        return provider_enrolment_details

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()

    def register_api_provider_enrolment_details(self, api_provider_enrolment_details, username, uuid):
        try:
            mycol = self.db.get_col_by_name(self.db.provider_enrolment_details)

            current_app.logger.debug("Creating api provider domain")
            search_filter = {'reg_sec': api_provider_enrolment_details.reg_sec}
            my_provider_enrolment_details = mycol.find_one(search_filter)

            if my_provider_enrolment_details is not None:
                current_app.logger.warning(
                    "Found provider registered with same id")
                return forbidden_error(detail="Provider already registered", cause="Identical provider reg sec")

            if not api_provider_enrolment_details.supp_feat:
                return bad_request_error(
                    detail="suppFeat not present in request",
                    cause="suppFeat not present",
                    invalid_params=[{"param": "suppFeat", "reason": "not defined"}]
                )

            api_provider_enrolment_details.api_prov_dom_id = secrets.token_hex(
                15)
            
            negotiated_supported_features = return_negotiated_supp_feat_dict(api_provider_enrolment_details.supp_feat)
            api_provider_enrolment_details.supp_feat = negotiated_supported_features["Final"]

            current_app.logger.debug("Generating certs to api prov funcs")

            for api_provider_func in api_provider_enrolment_details.api_prov_funcs:
                api_provider_func.api_prov_func_id = api_provider_func.api_prov_func_role + \
                    str(secrets.token_hex(15))
                try:
                    certificate = sign_certificate(
                        api_provider_func.reg_info.api_prov_pub_key, api_provider_func.api_prov_func_id)
                    api_provider_func.reg_info.api_prov_cert = certificate
                except Exception as e:
                    current_app.logger.error(f"Certificate signing failed: {str(e)}")
                    return bad_request_error(
                        detail="Certificate signing failed",
                        cause=str(e),
                        invalid_params=[{"param": "apiProvPubKey", "reason": "Invalid public key format or certificate signing error"}]
                    )

                self.auth_manager.add_auth_provider(certificate, api_provider_func.api_prov_func_id,
                                                    api_provider_func.api_prov_func_role, api_provider_enrolment_details.api_prov_dom_id)

            # Onboarding Date Record
            provider_dict = api_provider_enrolment_details.to_dict()
            provider_dict["onboarding_date"] = datetime.now()
            provider_dict["username"] = username
            provider_dict["uuid"] = uuid

            mycol.insert_one(provider_dict)

            current_app.logger.info("Provider inserted in database")

            res = make_response(object=serialize_clean_camel_case(
                api_provider_enrolment_details), status=201)

            res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/api-provider-management/v1/registrations/{str(api_provider_enrolment_details.api_prov_dom_id)}"
            return res

        except Exception as e:
            exception = "An exception occurred in register provider"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def delete_api_provider_enrolment_details(self, api_prov_dom_id):
        try:
            mycol = self.db.get_col_by_name(self.db.provider_enrolment_details)

            current_app.logger.debug("Deleting provider domain")
            result = self.__check_api_provider_domain(api_prov_dom_id)

            if isinstance(result, Response):
                return result

            func_ids = list()
            for provider_func in result["api_prov_funcs"]:
                func_ids.append(provider_func['api_prov_func_id'])
            apf_ids = [provider_func['api_prov_func_id']
                       for provider_func in result["api_prov_funcs"] if provider_func['api_prov_func_role'] == 'APF']
            aef_ids = [provider_func['api_prov_func_id']
                       for provider_func in result["api_prov_funcs"] if provider_func['api_prov_func_role'] == 'AEF']
            amf_ids = [provider_func['api_prov_func_id']
                       for provider_func in result["api_prov_funcs"] if provider_func['api_prov_func_role'] == 'AMF']

            mycol.delete_one({'api_prov_dom_id': api_prov_dom_id})
            out = "The provider matching apiProvDomainId  " + \
                api_prov_dom_id + " was offboarded."
            current_app.logger.info("Removed provider domain from database")

            self.auth_manager.remove_auth_provider(func_ids)

            RedisInternalEvent("PROVIDER-REMOVED",
                               "providerIds",
                               {
                                   "apf_ids": apf_ids,
                                   "aef_ids": aef_ids,
                                   "amf_ids": amf_ids,
                                   "all_ids": apf_ids + aef_ids + amf_ids
                               }).send_event()

            return make_response(object=out, status=204)

        except Exception as e:
            exception = "An exception occurred in delete provider"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def update_api_provider_enrolment_details(self, api_prov_dom_id, api_provider_enrolment_details):
        try:
            mycol = self.db.get_col_by_name(self.db.provider_enrolment_details)

            current_app.logger.debug("Updating api provider domain")
            result = self.__check_api_provider_domain(api_prov_dom_id)

            if isinstance(result, Response):
                return result

            if not api_provider_enrolment_details.supp_feat:
                return bad_request_error(
                    detail="suppFeat not present in request",
                    cause="suppFeat not present",
                    invalid_params=[{"param": "suppFeat", "reason": "not defined"}]
                )

            negotiated_supported_features = return_negotiated_supp_feat_dict(api_provider_enrolment_details.supp_feat)
            api_provider_enrolment_details.supp_feat = negotiated_supported_features["Final"]

            for func in api_provider_enrolment_details.api_prov_funcs:
                if func.api_prov_func_id is None:
                    func.api_prov_func_id = func.api_prov_func_role + \
                        str(secrets.token_hex(15))
                    try:
                        certificate = sign_certificate(
                            func.reg_info.api_prov_pub_key, func.api_prov_func_id)
                        func.reg_info.api_prov_cert = certificate
                    except Exception as e:
                        current_app.logger.error(f"Certificate signing failed: {str(e)}")
                        return bad_request_error(
                            detail="Certificate signing failed",
                            cause=str(e),
                            invalid_params=[{"param": "apiProvPubKey", "reason": "Invalid public key format"}]
                        )

                    self.auth_manager.update_auth_provider(
                        certificate, func.api_prov_func_id, api_prov_dom_id, func.api_prov_func_role)
                else:
                    api_prov_funcs = result["api_prov_funcs"]
                    for api_func in api_prov_funcs:
                        if func.api_prov_func_id == api_func["api_prov_func_id"]:
                            if func.api_prov_func_role != api_func["api_prov_func_role"]:
                                return bad_request_error(detail="Bad Role in provider", cause="Different role in update reqeuest", invalid_params=[{"param": "api_prov_func_role", "reason": "different role with same id"}])
                            if func.reg_info.api_prov_pub_key != api_func["reg_info"]["api_prov_pub_key"]:
                                try:
                                    certificate = sign_certificate(
                                        func.reg_info.api_prov_pub_key, api_func["api_prov_func_id"])
                                    func.reg_info.api_prov_cert = certificate
                                except Exception as e:
                                    current_app.logger.error(f"Certificate signing failed: {str(e)}")
                                    return bad_request_error(
                                        detail="Certificate signing failed",
                                        cause=str(e),
                                        invalid_params=[{"param": "apiProvPubKey", "reason": "Invalid public key format or certificate signing error"}]
                                    )
                                self.auth_manager.update_auth_provider(
                                    certificate, func.api_prov_func_id, api_prov_dom_id, func.api_prov_func_role)

            api_provider_enrolment_details = api_provider_enrolment_details.to_dict()
            api_provider_enrolment_details = clean_empty(
                api_provider_enrolment_details)

            result = mycol.find_one_and_update(result, {"$set": api_provider_enrolment_details}, projection={
                                               '_id': 0}, return_document=ReturnDocument.AFTER, upsert=False)
            result = clean_empty(result)

            current_app.logger.info("Provider domain updated in database")
            provider_updated = APIProviderEnrolmentDetails().from_dict(dict_to_camel_case(result))

            return make_response(object=serialize_clean_camel_case(provider_updated), status=200)

        except Exception as e:
            exception = "An exception occurred in update provider"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def patch_api_provider_enrolment_details(self, api_prov_dom_id, api_provider_enrolment_details_patch):
        try:
            mycol = self.db.get_col_by_name(self.db.provider_enrolment_details)

            current_app.logger.debug("Updating api provider domain")
            result = self.__check_api_provider_domain(api_prov_dom_id)

            if isinstance(result, Response):
                return result

            api_provider_enrolment_details_patch = api_provider_enrolment_details_patch.to_dict()
            api_provider_enrolment_details_patch = clean_empty(
                api_provider_enrolment_details_patch)

            result = mycol.find_one_and_update(result, {"$set": api_provider_enrolment_details_patch}, projection={
                                               '_id': 0}, return_document=ReturnDocument.AFTER, upsert=False)

            result = clean_empty(result)

            current_app.logger.info("Provider domain updated in database")
            provider_updated = APIProviderEnrolmentDetails().from_dict(dict_to_camel_case(result))

            return make_response(object=serialize_clean_camel_case(provider_updated), status=200)

        except Exception as e:
            exception = "An exception occurred in patch provider"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
