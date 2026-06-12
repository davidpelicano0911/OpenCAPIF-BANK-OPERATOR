import json

from ..encoder import CustomJSONEncoder
from .publisher import Publisher

publisher_ops = Publisher()


class RedisEvent():
    def __init__(self,
                 event,
                 service_api_descriptions=None,
                 api_ids=None,
                 api_invoker_ids=None,
                 acc_ctrl_pol_list=None,
                 invocation_logs=None,
                 api_topo_hide=None) -> None:
        self.EVENTS_ENUM = [
            'SERVICE_API_AVAILABLE',
            'SERVICE_API_UNAVAILABLE',
            'SERVICE_API_UPDATE',
            'API_INVOKER_ONBOARDED',
            'API_INVOKER_OFFBOARDED',
            'SERVICE_API_INVOCATION_SUCCESS',
            'SERVICE_API_INVOCATION_FAILURE',
            'ACCESS_CONTROL_POLICY_UPDATE',
            'ACCESS_CONTROL_POLICY_UNAVAILABLE',
            'API_INVOKER_AUTHORIZATION_REVOKED',
            'API_INVOKER_UPDATED',
            'API_TOPOLOGY_HIDING_CREATED',
            'API_TOPOLOGY_HIDING_REVOKED']
        if event not in self.EVENTS_ENUM:
            raise Exception(
                "Event (" + event + ") is not on event enum (" + ','.join(self.EVENTS_ENUM) + ")")
        self.redis_event = {
            "event": event
        }
        # Add event filter keys to an auxiliary object
        event_detail = {
            "serviceAPIDescriptions": service_api_descriptions,
            "apiIds": api_ids,
            "apiInvokerIds": api_invoker_ids,
            "accCtrlPolList": acc_ctrl_pol_list,
            "invocationLogs": invocation_logs,
            "apiTopoHide": api_topo_hide
        }

        # Filter keys with not None values
        filtered_event_detail = {k: v for k,
                                 v in event_detail.items() if v is not None}

        # If there are valid values then add to redis event.
        if filtered_event_detail:
            self.redis_event["event_detail"] = filtered_event_detail

    def to_string(self):
        return json.dumps(self.redis_event, cls=CustomJSONEncoder)

    def send_event(self):
        publisher_ops.publish_message("events", self.to_string())

    def __call__(self):
        return self.redis_event
