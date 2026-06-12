# subscriber.py
import json

import redis
from config import Config
from flask import current_app

from .internal_service_ops import InternalServiceOps


class Subscriber():

    def __init__(self):
        self.config = Config().get_config()
        # set this params using config params
        self.r = redis.Redis(
            host=self.config["redis"]["host"], port=self.config["redis"]["port"], db=self.config["redis"]["db"])
        self.acls_ops = InternalServiceOps()
        self.p = self.r.pubsub()
        self.p.subscribe("acls-messages", "internal-messages")

    def listen(self):
        for raw_message in self.p.listen():
            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "acls-messages":
                current_app.logger.debug("acls-messages recived")
                message, *ids = raw_message["data"].decode('utf-8').split(":")
                if message == "create-acl" and len(ids) == 3:
                    self.acls_ops.create_acl(ids[0], ids[1], ids[2])
                if message == "remove-acl" and len(ids) == 3:
                    self.acls_ops.remove_acl(ids[0], ids[1], ids[2])
                if message == "remove-acl" and len(ids) == 1:
                    self.acls_ops.remove_invoker_acl(ids[0])

            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "internal-messages":
                current_app.logger.debug("New internal event received")
                internal_redis_event = json.loads(
                    raw_message["data"].decode('utf-8'))
                if internal_redis_event.get('event') == "INVOKER-REMOVED":
                    api_invoker_id = internal_redis_event.get(
                        'information', {"api_invoker_id": None}).get('api_invoker_id')
                    if api_invoker_id is not None:
                        self.acls_ops.remove_invoker_acl(api_invoker_id)
                elif internal_redis_event.get('event') == "PROVIDER-REMOVED":
                    aef_ids = internal_redis_event.get(
                        'information', {"aef_ids": []}).get('aef_ids')
                    if len(aef_ids) > 0:
                        for aef_id in aef_ids:
                            self.acls_ops.remove_provider_acls(aef_id)
