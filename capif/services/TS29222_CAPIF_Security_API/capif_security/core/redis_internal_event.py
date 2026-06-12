import json

from ..encoder import JSONEncoder
from .publisher import Publisher

publisher_ops = Publisher()


class RedisInternalEvent():
    def __init__(self, event, event_detail_key=None, information=None) -> None:
        self.INTERNAL_MESSAGES = [
            'INVOKER-REMOVED',
            'PROVIDER-REMOVED',
            'SECURITY-CONTEXT-CREATED',
            'SECURITY-CONTEXT-REMOVED',
            'create-acl',
            'remove-acl',
        ]
        if event not in self.INTERNAL_MESSAGES:
            raise Exception(
                "Internal Message (" + event + ") is not on INTERNAL_MESSAGES enum (" + ','.join(self.INTERNAL_MESSAGES) + ")")
        self.redis_event = {
            "event": event
        }
        if event_detail_key is not None and information is not None:
            self.redis_event['key'] = event_detail_key
            self.redis_event['information'] = information

    def to_string(self):
        return json.dumps(self.redis_event, cls=JSONEncoder)

    def send_event(self):
        publisher_ops.publish_message("internal-messages", self.to_string())

    def __call__(self):
        return self.redis_event
