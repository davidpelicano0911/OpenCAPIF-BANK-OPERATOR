class CapifUserManager():
    def __init__(self):
        self.capif_users = {}
        self.register_users = {}

    def update_register_users(self, uuid, username):
        self.register_users[uuid] = username

    def update_capif_users_dicts(self, key, value):
        self.capif_users[key] = value

    def remove_capif_users_entry(self, key):
        self.capif_users.pop(key)

    def remove_register_users_entry(self, uuid=None, username=None):
        if uuid != None:
            self.register_users.pop(uuid)
        elif username != None:
            uuid=self.get_user_uuid(username)
            self.register_users.pop(uuid)

    def get_capif_users_dict(self):
        return self.capif_users

    def get_register_users_dict(self):
        return self.register_users
    
    def get_user_uuid(self, username):
        for uuid, stored_user in self.register_users.items():
            if stored_user == username:
                return uuid
        return None

CAPIF_USERS = CapifUserManager()