# subscriber.py
import json

import redis
from flask import current_app

from .internal_security_ops import InternalSecurityOps


class Subscriber():

    def __init__(self):
        self.r = redis.Redis(host='redis', port=6379, db=0)
        self.security_ops = InternalSecurityOps()
        self.p = self.r.pubsub()
        self.p.subscribe("internal-messages", "acls-messages")

    def listen(self):
        current_app.logger.debug("Listening security context messages")
        for raw_message in self.p.listen():
            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "internal-messages":
                internal_redis_event = json.loads(
                    raw_message["data"].decode('utf-8'))
                if internal_redis_event.get('event') == "INVOKER-REMOVED":
                    api_invoker_id = internal_redis_event.get(
                        'information', {"api_invoker_id": None}).get('api_invoker_id')
                    if api_invoker_id is not None:
                        self.security_ops.delete_intern_servicesecurity(api_invoker_id)
                elif internal_redis_event.get('event') == "PROVIDER-REMOVED":
                    aef_ids = internal_redis_event.get(
                        'information', {"aef_ids": []}).get("aef_ids")
                    if len(aef_ids) > 0:
                        self.security_ops.update_intern_servicesecurity(aef_ids)
