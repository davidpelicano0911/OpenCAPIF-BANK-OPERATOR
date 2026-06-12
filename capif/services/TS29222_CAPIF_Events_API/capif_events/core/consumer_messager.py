# subscriber.py
import json

import redis
from flask import current_app

from .internal_event_ops import InternalEventOperations
from .notifications import Notifications


class Subscriber():

    def __init__(self):
        self.r = redis.Redis(host='redis', port=6379, db=0)
        self.notification = Notifications()
        self.event_ops = InternalEventOperations()
        self.p = self.r.pubsub()
        self.p.subscribe("events", "internal-messages")

    def listen(self):
        for raw_message in self.p.listen():
            current_app.logger.debug(raw_message)
            if raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "events":
                current_app.logger.debug("Event received")
                redis_event = json.loads(raw_message["data"].decode('utf-8'))
                current_app.logger.debug(json.dumps(redis_event, indent=4))
                self.notification.send_notifications(redis_event)
            elif raw_message["type"] == "message" and raw_message["channel"].decode('utf-8') == "internal-messages":
                current_app.logger.debug("New internal event received")
                internal_redis_event = json.loads(
                    raw_message["data"].decode('utf-8'))
                if internal_redis_event.get('event') == "INVOKER-REMOVED":
                    api_invoker_id = internal_redis_event.get(
                        'information', {"api_invoker_id": None}).get('api_invoker_id')
                    if api_invoker_id is not None:
                        self.event_ops.delete_all_events([api_invoker_id])
                elif internal_redis_event.get('event') == "PROVIDER-REMOVED":
                    all_ids = internal_redis_event.get(
                        'information', {"all_ids": None}).get('all_ids')
                    if all_ids is not None:
                        self.event_ops.delete_all_events(all_ids)
