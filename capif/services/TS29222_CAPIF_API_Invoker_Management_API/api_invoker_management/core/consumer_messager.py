# subscriber.py
import json

import redis
from flask import current_app

from .invoker_internal_ops import InvokerInternalOperations


class Subscriber():

    def __init__(self):
        self.r = redis.Redis(host='redis', port=6379, db=0)
        self.invoker_ops = InvokerInternalOperations()
        self.p = self.r.pubsub()
        self.p.subscribe("internal-messages")

    def listen(self):
        for raw_message in self.p.listen():
            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "internal-messages":
                current_app.logger.debug("New internal event received")
                internal_redis_event = json.loads(
                    raw_message["data"].decode('utf-8'))
                if internal_redis_event.get('event') == "SECURITY-CONTEXT-CREATED":
                    current_app.logger.debug(
                        "Internal message received, updating Api list on invoker")
                    security_context_information = internal_redis_event.get(
                        'information', None)
                    if security_context_information is not None:
                        api_invoker_id = security_context_information.get(
                            'api_invoker_id')
                        api_id = security_context_information.get('api_id')
                        self.invoker_ops.update_services_list(
                            api_invoker_id, api_id)
                elif internal_redis_event.get('event') == "SECURITY-CONTEXT-REMOVED":
                    current_app.logger.debug(
                        "Internal message received, removing service in  Api list of invoker")
                    security_context_information = internal_redis_event.get(
                        'information', None)
                    if security_context_information is not None:
                        api_invoker_id = security_context_information.get(
                            'api_invoker_id')
                        api_id = security_context_information.get('api_id')
                        self.invoker_ops.remove_services_list(
                            api_invoker_id, api_id)
                # elif internal_redis_event.get('event') == "INVOKER-REMOVED":
                #     api_invoker_id = internal_redis_event.get(
                #         'information', {"api_invoker_id": None}).get('api_invoker_id')
                #     if api_invoker_id is not None:
                #         self.acls_ops.remove_invoker_acl(api_invoker_id)
                # elif internal_redis_event.get('event') == "PROVIDER-REMOVED":
                #     aef_ids = internal_redis_event.get(
                #         'information', {"aef_ids": []}).get('aef_ids')
                #     if len(aef_ids) > 0:
                #         self.acls_ops.remove_provider_acls(aef_ids[0])
