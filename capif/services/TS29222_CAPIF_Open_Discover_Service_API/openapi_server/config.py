import os

import yaml


class Config:
    def __init__(self):
        self.cached = 0
        self.file = "../config.yaml"
        self.my_config = {}

        stamp = os.stat(self.file).st_mtime
        if stamp != self.cached:
            self.cached = stamp
            with open(self.file) as f:
                self.my_config = yaml.safe_load(f)

    def get_config(self):
        return self.my_config
