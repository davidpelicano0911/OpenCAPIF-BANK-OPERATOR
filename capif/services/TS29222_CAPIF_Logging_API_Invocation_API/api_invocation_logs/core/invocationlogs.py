
import json
import os
import secrets

from flask import current_app
from pymongo import ReturnDocument

from ..encoder import CustomJSONEncoder
from ..util import serialize_clean_camel_case
from .redis_event import RedisEvent
from .resources import Resource
from .responses import (internal_server_error, make_response, not_found_error,
                        unauthorized_error)

TOTAL_FEATURES = 1
SUPPORTED_FEATURES_HEX = "0"

def return_negotiated_supp_feat_dict(supp_feat):

    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]

    return {
        "SliceBasedAPIExposure": True if final_supp_feat[0] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }

class LoggingInvocationOperations(Resource):

    def __check_aef(self, request_aef_id, body_aef_id):

        prov_col = self.db.get_col_by_name(self.db.provider_details)

        current_app.logger.debug("Checking aef id")
        aef_res = prov_col.find_one({'api_prov_funcs': {'$elemMatch': {
                                    'api_prov_func_role': 'AEF', 'api_prov_func_id': request_aef_id}}})

        if aef_res is None:
            current_app.logger.warning("Exposer not exist")
            return not_found_error(detail="Exposer not exist", cause="Exposer id not found")

        if request_aef_id != body_aef_id:
            return unauthorized_error(detail="AEF id not matching in request and body", cause="Not identical AEF id")

        return None

    def __check_invoker(self, invoker_id):
        inv_col = self.db.get_col_by_name(self.db.invoker_details)

        current_app.logger.debug("Checking invoker id")
        invoker_res = inv_col.find_one({'api_invoker_id': invoker_id})

        if invoker_res is None:
            current_app.logger.warning("Invoker not exist")
            return not_found_error(detail="Invoker not exist", cause="Invoker id not found")

        return None

    def __check_service_apis(self, api_id, api_name):
        serv_apis = self.db.get_col_by_name(self.db.service_apis)

        current_app.logger.debug("Checking service apis")
        services_api_res = serv_apis.find_one(
            {"$and": [{'api_id': api_id}, {'api_name': api_name}]})

        if services_api_res is None:
            detail = "Service API not exist"
            cause = "Service API with id {} and name {} not found".format(
                api_id, api_name)
            current_app.logger.warning(detail)
            return not_found_error(detail=detail, cause=cause)

        return None

    def add_invocationlog(self, aef_id, invocationlog):

        mycol = self.db.get_col_by_name(self.db.invocation_logs)

        try:
            current_app.logger.debug("Adding invocation logs")
            current_app.logger.debug("Check request aef_id")
            result = self.__check_aef(aef_id, invocationlog.aef_id)

            if result is not None:
                return result

            current_app.logger.debug("Check request api_invoker_id")
            result = self.__check_invoker(invocationlog.api_invoker_id)

            if result is not None:
                return result

            invocationlog.supported_features = return_negotiated_supp_feat_dict(invocationlog.supported_features)["Final"]

            current_app.logger.debug("Check service apis")
            event = None
            invocation_log_base = json.loads(json.dumps(
                invocationlog.to_dict(), cls=CustomJSONEncoder))

            for log in invocationlog.logs:
                result = self.__check_service_apis(log.api_id, log.api_name)

                current_app.logger.debug("Inside for loop.")
                if result is not None:
                    return result

                if log.result:
                    current_app.logger.debug(log)
                    if int(log.result) >= 200 and int(log.result) < 300:
                        event = "SERVICE_API_INVOCATION_SUCCESS"
                    else:
                        event = "SERVICE_API_INVOCATION_FAILURE"

                    current_app.logger.debug(event)
                    invocation_log_base['logs'] = [log.to_dict()]
                    invocationLogs = [invocation_log_base]
                    RedisEvent(event, invocation_logs=
                               invocationLogs).send_event()

            current_app.logger.debug("After log check")

            current_app.logger.debug("Check existing logs")
            my_query = {'aef_id': aef_id,
                        'api_invoker_id': invocationlog.api_invoker_id}
            existing_invocationlog = mycol.find_one(my_query)

            if existing_invocationlog is None:
                current_app.logger.debug("Create new log")
                log_id = secrets.token_hex(15)
                rec = dict()
                rec['log_id'] = log_id
                rec.update(invocationlog.to_dict())
                mycol.insert_one(rec)
            else:
                current_app.logger.debug("Update existing log")
                log_id = existing_invocationlog['log_id']
                updated_invocation_logs = invocationlog.to_dict()
                for updated_invocation_log in updated_invocation_logs['logs']:
                    existing_invocationlog['logs'].append(
                        updated_invocation_log)
                mycol.find_one_and_update(my_query, {"$set": existing_invocationlog}, projection={
                                          '_id': 0, 'log_id': 0}, return_document=ReturnDocument.AFTER, upsert=False)

            res = make_response(object=serialize_clean_camel_case(
                invocationlog), status=201)
            current_app.logger.info("Invocation Logs response ready")

            apis_added = {
                log.api_id: log.api_name for log in invocationlog.logs}

            current_app.logger.debug(f"Added log entry to apis: {apis_added}")
            res.headers['Location'] = f"https://{os.getenv("CAPIF_HOSTNAME")}/api-invocation-logs/v1/{str(aef_id)}/logs/{str(log_id)}"

            return res

        except Exception as e:
            exception = "An exception occurred in inserting invocation logs"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))
