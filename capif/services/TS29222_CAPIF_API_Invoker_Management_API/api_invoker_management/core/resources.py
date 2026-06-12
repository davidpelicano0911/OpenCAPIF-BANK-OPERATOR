from abc import ABC

from api_invoker_management.db.db import MongoDatabse


class Resource(ABC):

    def __init__(self):
        self.db = MongoDatabse()