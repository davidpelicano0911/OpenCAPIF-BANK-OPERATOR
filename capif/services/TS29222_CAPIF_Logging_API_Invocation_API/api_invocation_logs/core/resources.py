from abc import ABC

from db.db import MongoDatabse


class Resource(ABC):

    def __init__(self):
        self.db = MongoDatabse()