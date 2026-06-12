import time

from config import Config
from pymongo import MongoClient
from pymongo.errors import AutoReconnect


class MongoDatabse():

    def __init__(self):
        self.config = Config().get_config()
        self.db = self.__connect()
        self.capif_users = self.config['mongo']['col']
        self.capif_admins = self.config['mongo']['admins']
        self.capif_configuration = self.config['mongo']['col_capif_configuration']
        
        self.initialize_capif_configuration()

    def get_col_by_name(self, name):
        return self.db[name]

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

    def initialize_capif_configuration(self):
        capif_col = self.get_col_by_name(self.capif_configuration)
        if capif_col.count_documents({}) == 0:
            default_config = self.config["capif_configuration"]
            capif_col.insert_one(default_config)
            print("Default data inserted into the capif_configuration collection from config.yaml")
        else:
            print("The capif_configuration collection already contains data. No default values were inserted.")

    def close_connection(self):
        if self.db.client:
            self.db.client.close()
