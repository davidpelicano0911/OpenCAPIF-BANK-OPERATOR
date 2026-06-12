from flask import current_app

from ..core.resources import Resource
from ..models.access_control_policy_list import AccessControlPolicyList
from ..util import serialize_clean_camel_case
from .responses import internal_server_error, make_response, not_found_error


class accessControlPolicyApi(Resource):
    def get_acl(self, service_api_id, aef_id, api_invoker_id, supported_features):

        mycol = self.db.get_col_by_name(self.db.acls)

        try:
            # api-invoker-id and supported-features are optional.
            # service-api-id and aef-id are mandatory parameters
            query={
                "service_id": service_api_id,
                "aef_id": aef_id

            }
            projection = {"_id":0}

            if api_invoker_id is not None:
                query['api_invoker_policies.api_invoker_id'] = api_invoker_id
                projection['api_invoker_policies.$'] = 1
            if supported_features is not None:
                current_app.logger.debug(f"SupportedFeatures present on query with value {supported_features}, but currently not used")
            
            current_app.logger.debug(f"Looking for ACLs of service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}")
            policies_cursor = mycol.find(query,projection)
            policies = list(policies_cursor)
            if not policies:
                current_app.logger.warning(f"No ACLs found for the requested service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}")
                #Not found error
                return not_found_error(f"No ACLs found for the requested service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}", "Wrong id")
            
            current_app.logger.debug(f"Returning ACL for service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}")

            current_app.logger.debug(policies)

            api_invoker_policies = policies[0]['api_invoker_policies']
            current_app.logger.debug(f"api_invoker_policies: {api_invoker_policies}")
            if not api_invoker_policies:
                current_app.logger.warning(f"ACLs list is present but empty, then no ACLs found for the requested service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}")
                #Not found error
                return not_found_error(f"No ACLs found for the requested service: {service_api_id}, aef_id: {aef_id}, invoker: {api_invoker_id} and supportedFeatures: {supported_features}", "Wrong id")
            acl = AccessControlPolicyList(api_invoker_policies)

            return make_response(object=serialize_clean_camel_case(acl), status=200)

        except Exception as e:
            exception = "An exception occurred in get acl"
            current_app.logger.error(exception + "::" + str(e))
            return internal_server_error(detail=exception, cause=str(e))