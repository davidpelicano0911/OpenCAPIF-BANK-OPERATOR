from datetime import datetime, timedelta

from flask import current_app
from models.api_invoker_policy import ApiInvokerPolicy
from models.time_range_list import TimeRangeList
from util import dict_to_camel_case

from .redis_event import RedisEvent
from .resources import Resource


class InternalServiceOps(Resource):

    def create_acl(self, invoker_id, service_id, aef_id):

        current_app.logger.debug(f"Creating ACL for invoker: {invoker_id}")

        if "acls" not in self.db.db.list_collection_names():
            self.db.db.create_collection("acls")

        mycol = self.db.get_col_by_name(self.db.acls)

        # Retrieve parameters from capif_configuration in MongoDB
        config_col = self.db.get_col_by_name("capif_configuration")
        capif_config = config_col.find_one({"config_name": "default"})

        if capif_config:
            settings = capif_config.get("settings", {}).get("acl_policy_settings", {})
            allowed_total_invocations = settings.get("allowed_total_invocations", 100)
            allowed_invocations_per_second = settings.get("allowed_invocations_per_second", 10)
            time_range_days = settings.get("allowed_invocation_time_range_days", 365)
        else:
            current_app.logger.error("CAPIF Configuration not found, applying all values to 0.")
            allowed_total_invocations = 0
            allowed_invocations_per_second = 0
            time_range_days = 0

        res = mycol.find_one(
            {"service_id": service_id, "aef_id": aef_id}, {"_id": 0})

        if res:
            current_app.logger.debug(
                f"Adding invoker ACL for invoker {invoker_id}")
            range_list = [TimeRangeList(
                datetime.utcnow(), datetime.utcnow()+timedelta(days=time_range_days))]
            invoker_acl = ApiInvokerPolicy(
                invoker_id, allowed_total_invocations, allowed_invocations_per_second, range_list)
            r = mycol.find_one({"service_id": service_id, "aef_id": aef_id,
                               "api_invoker_policies.api_invoker_id": invoker_id}, {"_id": 0})
            if r is None:
                mycol.update_one({"service_id": service_id, "aef_id": aef_id}, {
                                 "$push": {"api_invoker_policies": invoker_acl.to_dict()}})
            
            inserted_invoker_acl = mycol.find_one({"service_id": service_id, "aef_id": aef_id,
                               "api_invoker_policies.api_invoker_id": invoker_id}, {"_id": 0})
            current_app.logger.debug(inserted_invoker_acl)
            inserted_invoker_acl_camel = dict_to_camel_case(inserted_invoker_acl)
            current_app.logger.debug(inserted_invoker_acl_camel)

            created_invoker_policy = next((policy for policy in inserted_invoker_acl_camel['apiInvokerPolicies'] if policy['apiInvokerId'] == invoker_id), None)

            accCtrlPolListExt = {
                "apiId": service_id,
                "apiInvokerPolicies": [created_invoker_policy]
            }
            RedisEvent("ACCESS_CONTROL_POLICY_UPDATE",
                       acc_ctrl_pol_list=accCtrlPolListExt).send_event()
            
        else:
            current_app.logger.debug(
                f"Creating service ACLs for service: {service_id}")
            range_list = [TimeRangeList(
                datetime.utcnow(), datetime.utcnow()+timedelta(days=time_range_days))]
            invoker_acl = ApiInvokerPolicy(
                invoker_id, allowed_total_invocations, allowed_invocations_per_second, range_list)

            service_acls = {
                "service_id": service_id,
                "aef_id": aef_id,
                "api_invoker_policies": [invoker_acl.to_dict()]
            }
            result = mycol.insert_one(service_acls)

            inserted_service_acls = mycol.find_one({"_id": result.inserted_id}, {"_id": 0})
            current_app.logger.debug(inserted_service_acls)
            inserted_service_acls_camel = dict_to_camel_case(inserted_service_acls)
            current_app.logger.debug(inserted_service_acls_camel)

            created_invoker_policy = next((policy for policy in inserted_service_acls_camel['apiInvokerPolicies'] if policy['apiInvokerId'] == invoker_id), None)

            accCtrlPolListExt = {
                "apiId": service_id,
                "apiInvokerPolicies": [created_invoker_policy]
            }
            RedisEvent("ACCESS_CONTROL_POLICY_UPDATE",
                       acc_ctrl_pol_list=accCtrlPolListExt).send_event()

        current_app.logger.info(
            f"Invoker ACL added for invoker: {invoker_id} for service: {service_id}")

    def remove_acl(self, invoker_id, service_id, aef_id):

        current_app.logger.debug(f"Removing ACL for invoker: {invoker_id}")

        mycol = self.db.get_col_by_name(self.db.acls)

        res = mycol.find_one(
            {"service_id": service_id, "aef_id": aef_id}, {"_id": 0})

        if res:
            mycol.update_many({"service_id": service_id, "aef_id": aef_id},
                              {"$pull": {"api_invoker_policies": {
                                  "api_invoker_id": invoker_id}}}
                              )
        else:
            current_app.logger.warning(
                f"Not found: {service_id} for api : {service_id}")

        RedisEvent("ACCESS_CONTROL_POLICY_UNAVAILABLE").send_event()

        current_app.logger.info(
            f"Invoker ACL removed for invoker: {invoker_id} for service: {service_id}")

    def remove_invoker_acl(self, invoker_id):

        current_app.logger.debug(f"Removing ACLs for invoker: {invoker_id}")
        mycol = self.db.get_col_by_name(self.db.acls)

        mycol.update_many({"api_invoker_policies.api_invoker_id": invoker_id},
                          {"$pull": {"api_invoker_policies": {
                              "api_invoker_id": invoker_id}}}
                          )
        RedisEvent("ACCESS_CONTROL_POLICY_UNAVAILABLE").send_event()
        current_app.logger.info(f"ACLs for invoker: {invoker_id} removed")

    def remove_provider_acls(self, id):

        current_app.logger.debug(f"Removing ACLs for provider/service: {id}")
        mycol = self.db.get_col_by_name(self.db.acls)

        mycol.delete_many({"$or": [{"service_id": id}, {"aef_id": id}]})
        RedisEvent("ACCESS_CONTROL_POLICY_UNAVAILABLE").send_event()
        current_app.logger.info(f"ACLs for provider/service: {id} removed")
