import secrets
import time
from threading import Lock

from bson.codec_options import CodecOptions
from config import Config
from pymongo import MongoClient
from pymongo.errors import AutoReconnect


class MongoDatabse():

    _instance = None
    _lock = Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:  # double-checked
                    cls._instance = super().__new__(cls)
                    cls._instance._init_once()
        return cls._instance

    def close(self):
        if getattr(self, "_client", None):
            self._client.close()
            self._client = None

    def get_col_by_name(self, name):
        return self.db[name].with_options(codec_options=CodecOptions(tz_aware=True))

    def _init_once(self):
        self.config = Config().get_config()
        self.db = self.__connect()
        self.invoker_col = self.config['mongo']['invoker_col']
        self.provider_col = self.config['mongo']['provider_col']
        self.services_col = self.config['mongo']['col_services']
        self.security_context_col = self.config['mongo']['col_security']
        self.events = self.config['mongo']['col_event']
        self.capif_configuration = self.config['mongo']['col_capif_configuration']

        self.initialize_capif_configuration()


    def get_col_by_name(self, name):
        return self.db[name].with_options(codec_options=CodecOptions(tz_aware=True))
    
    def __connect(self, max_retries=3, retry_delay=1):

        retries = 0

        while retries < max_retries:
            try:
                uri = f"mongodb://{self.config['mongo']['user']}:{self.config['mongo']['password']}@" \
                      f"{self.config['mongo']['host']}:{self.config['mongo']['port']}"

                
                client = MongoClient(uri)
                mydb = client[self.config['mongo']['db']]
                mydb.command("ping")
                return mydb
            except AutoReconnect:
                retries += 1
                print(f"Reconnecting... Retry {retries} of {max_retries}")
                time.sleep(retry_delay)
        return None

    def close_connection(self):
        if self.db.client:
            self.db.client.close()

    def initialize_capif_configuration(self):
        """
        Inserts default data into the capif_configuration collection if it is empty.
        The data is taken from config.yaml.
        """
        capif_col = self.get_col_by_name(self.capif_configuration)

        if capif_col.count_documents({}) == 0:
            # Read configuration from config.yaml
            default_config = self.config["capif_configuration"]

            # Generate unique ccf_id
            ccf_id = "CCF" + secrets.token_hex(15)
            default_config["ccf_id"] = ccf_id

            capif_col.insert_one(default_config)
            print(f"Default data inserted into capif_configuration from config.yaml with ccf_id={ccf_id}")

        else:
            # Ensure ccf_id exists even if config already there
            existing_config = capif_col.find_one({}, {"_id": 0})
            if "ccf_id" not in existing_config:
                ccf_id = "CCF" + secrets.token_hex(15)
                capif_col.update_one({}, {"$set": {"ccf_id": ccf_id}})
                print(f"Added missing ccf_id={ccf_id} to existing CAPIF configuration")
            else:
                print("Capif_configuration already contains data with a unique ccf_id. No default values inserted.")


_singleton = None
def get_mongo():
    global _singleton
    if _singleton is None:
        _singleton = MongoDatabse()
    return _singleton