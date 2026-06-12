
import json

from flask import current_app

from ..models.invocation_log import InvocationLog
from ..util import serialize_clean_camel_case
from .resources import Resource
from .responses import (bad_request_error, internal_server_error,
                        make_response, not_found_error)

TOTAL_FEATURES = 2
SUPPORTED_FEATURES_HEX = "1"

def return_negotiated_supp_feat_dict(supp_feat):
    final_supp_feat = bin(int(supp_feat, 16) & int(SUPPORTED_FEATURES_HEX, 16))[2:].zfill(TOTAL_FEATURES)[::-1]
    return {
        "EnQueryInvokeLog": True if final_supp_feat[0] == "1" else False,
        "SliceBasedAPIExposure": True if final_supp_feat[1] == "1" else False,
        "Final": hex(int(final_supp_feat[::-1], 2))[2:]
    }

class AuditOperations (Resource):

    def get_logs(self, query_parameters):

        mycol = self.db.get_col_by_name(self.db.invocation_logs)

        current_app.logger.debug("Find invocation logs")

        try:
            result = mycol.find_one({'aef_id': query_parameters['aef_id'], 'api_invoker_id': query_parameters['api_invoker_id']}, {"_id": 0})

            if result is None:
                return not_found_error(detail="aefId or/and apiInvokerId do not match any InvocationLogs", cause="No log invocations found")

            logs = result['logs'].copy()

            query_params = dict((k,v) for k,v in query_parameters.items() if v is not None and k != 'aef_id' and k != 'api_invoker_id')

            for log in logs:

                for param in query_params:
                    if param == 'time_range_start':
                        if query_params[param] > log['invocation_time'].astimezone(query_params[param].tzinfo):
                            result['logs'].remove(log)
                            break
                    elif param == 'time_range_end':
                        if query_params[param] < log['invocation_time'].astimezone(query_params[param].tzinfo):
                            result['logs'].remove(log)
                            break
                    elif param == 'src_interface' or param == 'dest_interface':
                        interface = json.loads(query_params[param])
                        if 'security_methods' not in interface:
                            return bad_request_error(detail="security_methods is mandatory",
                                                     cause="security_methods parameter missing", invalid_params=[
                                    {"param": "security_methods", "reason": "missing"}])
                        for key in interface:
                            if log[param][key] != interface[key]:
                                result['logs'].remove(log)
                                break
                    elif log[param] != query_params[param]:
                        result['logs'].remove(log)
                        break

            if not result['logs']:
                return not_found_error(detail="Parameters do not match any log entry", cause="No logs found")

            client_features = query_parameters.get('supported_features')
            if client_features:
                negotiated = return_negotiated_supp_feat_dict(client_features)
                result['supported_features'] = negotiated["Final"]
            else:
                result['supported_features'] = client_features

            invocation_log = InvocationLog(result['aef_id'], result['api_invoker_id'], result['logs'],
                                           result['supported_features'])
            res = make_response(object=serialize_clean_camel_case(invocation_log), status=200)
            current_app.logger.debug("Found invocation logs")
            return res

        except Exception as e:
            exception = "An exception occurred in audit"
            return internal_server_error(detail=exception, cause=str(e))

