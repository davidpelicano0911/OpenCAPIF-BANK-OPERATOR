import json
import os
import secrets
from datetime import datetime

import requests
import rfc3987
from api_invoker_management.db.db import MongoDatabse
from api_invoker_management.models.api_invoker_enrolment_details import \
    APIInvokerEnrolmentDetails
from flask import Response, current_app
from pymongo import ReturnDocument

from ..config import Config
from ..util import clean_empty, dict_to_camel_case, serialize_clean_camel_case
from .auth_manager import AuthManager
from .publisher import Publisher
from .redis_event import RedisEvent
from .redis_internal_event import RedisInternalEvent
from .resources import Resource
from .responses import (bad_request_error, forbidden_error,
                        internal_server_error, make_response, not_found_error)

TOTAL_FEATURES = 4
SUPPORTED_FEATURES_HEX = "0"


def return_negotiated_supp_feat_dict(supp_feat):

    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "Notification_test_event": True if final_supp_feat[0] == "1" else False,
        "Notification_websocket": True if final_supp_feat[1] == "1" else False,
        "PatchUpdate": True if final_supp_feat[2] == "1" else False,
        "ExpirationTime": True if final_supp_feat[3] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }


publisher_ops = Publisher()


class InvokerManagementOperations(Resource):

    def __check_api_invoker_id(self, api_invoker_id):

        current_app.logger.debug("Cheking api invoker id")
        mycol = self.db.get_col_by_name(self.db.invoker_enrolment_details)
        my_query = {'api_invoker_id': api_invoker_id}
        old_values = mycol.find_one(my_query)

        if old_values is None:
            current_app.logger.warning("Not found api invoker id")
            return not_found_error(detail="Please provide an existing Network App ID", cause="Not exist Network App ID")

        return old_values

    def __sign_cert(self, publick_key, invoker_id):

        capif_config = self.db.get_col_by_name("capif_configuration").find_one({"config_name": "default"})
        ttl_invoker_cert = capif_config.get("settings", {}).get("certificates_expiry", {}).get("ttl_invoker_cert", "4300h")

        url = f"http://{self.config['ca_factory']['url']}:{self.config['ca_factory']['port']}/v1/pki_int/sign/my-ca"
        headers = {'X-Vault-Token': self.config['ca_factory']['token']}
        data = {
            'format': 'pem_bundle',
            'ttl': ttl_invoker_cert,
            'csr': publick_key,
            'common_name': invoker_id
        }

        response = requests.request("POST", url, headers=headers, data=data,
                                    verify=self.config["ca_factory"].get("verify", False))
        print(response)
        response_payload = json.loads(response.text)

        return response_payload

    def __init__(self):
        Resource.__init__(self)
        self.auth_manager = AuthManager()
        self.config = Config().get_config()
        self.db = MongoDatabse()

    def add_apiinvokerenrolmentdetail(self, apiinvokerenrolmentdetail, username, uuid):

        mycol = self.db.get_col_by_name(self.db.invoker_enrolment_details)

        # try:
        current_app.logger.debug("Creating invoker resource")
        res = mycol.find_one({'onboarding_information.api_invoker_public_key':
                             apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key})

        if res is not None:
            current_app.logger.warning(
                "Generating forbbiden error, invoker registered")
            return forbidden_error(detail="Invoker already registered", cause="Identical invoker public key")

        if rfc3987.match(apiinvokerenrolmentdetail.notification_destination, rule="URI") is None:
            current_app.logger.warning("Bad url format")
            return bad_request_error(detail="Bad Param", cause="Detected Bad formar of param", invalid_params=[{"param": "notificationDestination", "reason": "Not valid URL format"}])

        if not apiinvokerenrolmentdetail.supported_features:
            return bad_request_error(
                detail="supportedFeatures not present in request",
                cause="supportedFeatures not present",
                invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
            )

        current_app.logger.debug("Signing Certificate")

        api_invoker_id = 'INV'+str(secrets.token_hex(15))
        cert = self.__sign_cert(
            apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key, api_invoker_id)

        apiinvokerenrolmentdetail.api_invoker_id = api_invoker_id
        current_app.logger.debug(cert)
        apiinvokerenrolmentdetail.onboarding_information.api_invoker_certificate = cert[
            'data']['certificate']

        apiinvokerenrolmentdetail.supported_features = return_negotiated_supp_feat_dict(apiinvokerenrolmentdetail.supported_features)["Final"]

        # Onboarding Date Record
        invoker_dict = apiinvokerenrolmentdetail.to_dict()
        invoker_dict["onboarding_date"] = datetime.now()
        invoker_dict["username"] = username
        invoker_dict["uuid"] = uuid

        mycol.insert_one(invoker_dict)

        current_app.logger.debug("Invoker inserted in database")
        current_app.logger.debug("Netapp onboarded sucessfuly")

        self.auth_manager.add_auth_invoker(
            cert['data']['certificate'], api_invoker_id)

        res = make_response(object=serialize_clean_camel_case(
            apiinvokerenrolmentdetail), status=201)
        res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/api-invoker-management/v1/onboardedInvokers/{str(api_invoker_id)}"

        if res.status_code == 201:
            current_app.logger.info("Invoker Created")
            RedisEvent("API_INVOKER_ONBOARDED",
                       api_invoker_ids=[str(api_invoker_id)]).send_event()
        return res

    def update_apiinvokerenrolmentdetail(self, onboard_id, apiinvokerenrolmentdetail):

        mycol = self.db.get_col_by_name(self.db.invoker_enrolment_details)

        try:
            current_app.logger.debug("Updating invoker resource")
            result = self.__check_api_invoker_id(onboard_id)

            if isinstance(result, Response):
                return result

            if not apiinvokerenrolmentdetail.supported_features:
                return bad_request_error(
                    detail="supportedFeatures not present in request",
                    cause="supportedFeatures not present",
                    invalid_params=[{"param": "supportedFeatures", "reason": "not defined"}]
                )

            if apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key != result["onboarding_information"]["api_invoker_public_key"]:
                cert = self.__sign_cert(
                    apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key, result["api_invoker_id"])
                apiinvokerenrolmentdetail.onboarding_information.api_invoker_certificate = cert[
                    'data']['certificate']
                self.auth_manager.update_auth_invoker(
                    cert['data']["certificate"], onboard_id)

            apiinvokerenrolmentdetail.supported_features = return_negotiated_supp_feat_dict(
                apiinvokerenrolmentdetail.supported_features)["Final"]
            
            apiinvokerenrolmentdetail.api_invoker_id = onboard_id
            apiinvokerenrolmentdetail_update = apiinvokerenrolmentdetail.to_dict()
            apiinvokerenrolmentdetail_update = clean_empty(apiinvokerenrolmentdetail_update)

            result = mycol.find_one_and_replace(result,
                                               apiinvokerenrolmentdetail_update,
                                               projection={'_id': 0},
                                               return_document=ReturnDocument.AFTER,
                                               upsert=False)


            current_app.logger.debug("Invoker Resource inserted in database")

            invoker_updated = APIInvokerEnrolmentDetails().from_dict(dict_to_camel_case(result))
            current_app.logger.debug(f"Invoker Updated: {invoker_updated}")

            res = make_response(object=serialize_clean_camel_case(
                invoker_updated), status=200)
            if res.status_code == 200:
                current_app.logger.info("Invoker Updated")
                RedisEvent("API_INVOKER_UPDATED",
                           api_invoker_ids=[onboard_id]).send_event()
            return res

        except Exception as e:
            exception = "An exception occurred in update invoker"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def patch_apiinvokerenrolmentdetail(self, onboard_id, apiinvokerenrolmentdetail):

        mycol = self.db.get_col_by_name(self.db.invoker_enrolment_details)

        try:
            current_app.logger.debug("Patching invoker resource")
            result = self.__check_api_invoker_id(onboard_id)

            if isinstance(result, Response):
                return result

            if apiinvokerenrolmentdetail.onboarding_information:
                if apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key != result["onboarding_information"]["api_invoker_public_key"]:
                    cert = self.__sign_cert(
                        apiinvokerenrolmentdetail.onboarding_information.api_invoker_public_key, result["api_invoker_id"])
                    apiinvokerenrolmentdetail.onboarding_information.api_invoker_certificate = cert[
                        'data']['certificate']
                    self.auth_manager.update_auth_invoker(
                        cert['data']["certificate"], onboard_id)
                else:
                    apiinvokerenrolmentdetail.onboarding_information.api_invoker_certificate = result["onboarding_information"]["api_invoker_certificate"]

            apiinvokerenrolmentdetail_update = apiinvokerenrolmentdetail.to_dict()
            apiinvokerenrolmentdetail_update = {
                key: value for key, value in apiinvokerenrolmentdetail_update.items() if value is not None
            }

            result = mycol.find_one_and_update(result,
                                               {"$set": apiinvokerenrolmentdetail_update},
                                               projection={'_id': 0},
                                               return_document=ReturnDocument.AFTER,
                                               upsert=False)

            result = {
                key: value for key, value in result.items() if value is not None
            }

            current_app.logger.debug("Invoker Resource inserted in database")

            invoker_updated = APIInvokerEnrolmentDetails().from_dict(dict_to_camel_case(result))

            res = make_response(object=serialize_clean_camel_case(
                invoker_updated), status=200)
            if res.status_code == 200:
                current_app.logger.info("Invoker Patched")
                RedisEvent("API_INVOKER_UPDATED",
                           api_invoker_ids=[onboard_id]).send_event()
            return res

        except Exception as e:
            exception = "An exception occurred in update invoker"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))

    def remove_apiinvokerenrolmentdetail(self, onboard_id):

        mycol = self.db.get_col_by_name(self.db.invoker_enrolment_details)
        try:
            current_app.logger.debug("Removing invoker resource")
            result = self.__check_api_invoker_id(onboard_id)

            if isinstance(result, Response):
                return result

            mycol.delete_one({'api_invoker_id': onboard_id})
            self.auth_manager.remove_auth_invoker(onboard_id)

            current_app.logger.debug("Invoker resource removed from database")
            current_app.logger.debug("Netapp offboarded sucessfuly")
            out = "The Network App matching onboardingId  " + onboard_id + " was offboarded."
            res = make_response(out, status=204)
            if res.status_code == 204:
                current_app.logger.info("Invoker Removed")
                RedisEvent("API_INVOKER_OFFBOARDED",
                           api_invoker_ids=[onboard_id]).send_event()
                RedisInternalEvent("INVOKER-REMOVED",
                                   "invokerId",
                                   {
                                       "api_invoker_id": onboard_id
                                   }).send_event()
            return res

        except Exception as e:
            exception = "An exception occurred in remove invoker"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
