from abc import ABC

from core.publisher import Publisher
from db.db import MongoDatabse


class Resource(ABC):

    def __init__(self):
        self.db = MongoDatabse()
        self.publish_ops = Publisher()