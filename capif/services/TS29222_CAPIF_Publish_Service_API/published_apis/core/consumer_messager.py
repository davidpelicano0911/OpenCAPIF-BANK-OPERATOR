# subscriber.py
import json

import redis
from flask import current_app

from .internal_service_ops import InternalServiceOps


class Subscriber():

    def __init__(self):
        self.r = redis.Redis(host='redis', port=6379, db=0)
        self.security_ops = InternalServiceOps()
        self.p = self.r.pubsub()
        self.p.subscribe("internal-messages")

    def listen(self):
        current_app.logger.debug("Listening publish messages")
        for raw_message in self.p.listen():
            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "internal-messages":
                current_app.logger.debug("New internal event received")
                internal_redis_event = json.loads(
                    raw_message["data"].decode('utf-8'))
                if internal_redis_event.get('event') == "PROVIDER-REMOVED":
                    apf_ids = internal_redis_event.get(
                        'information', {"apf_ids": []}).get('apf_ids')
                    if len(apf_ids) > 0:
                        self.security_ops.delete_intern_service(apf_ids)

