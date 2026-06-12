import os
import uuid
from datetime import datetime

import requests
from config import Config
from db.db import MongoDatabse
from flask import current_app, jsonify
from flask_jwt_extended import create_access_token
from utils.auth_utils import hash_password
from utils.utils import (convert_dict_keys_to_snake_case, to_snake_case,
                         validate_snake_case_keys)


class RegisterOperations:

    def __init__(self):
        self.db = MongoDatabse()
        self.mimetype = 'application/json'
        self.config = Config().get_config()

    def register_user(self, user_info):

        mycol = self.db.get_col_by_name(self.db.capif_users)
        exist_user = mycol.find_one({"username": user_info["username"]})
        if exist_user:
            current_app.logger.warning(f"User already exists : {user_info["username"]}")
            return jsonify("user already exists"), 409
        
        name_space = uuid.UUID(self.config["register"]["register_uuid"])
        user_uuid = str(uuid.uuid5(name_space,user_info["username"]))
        current_app.logger.debug(f"User uuid : {user_uuid}")

        user_info["uuid"] = user_uuid
        user_info["onboarding_date"]=datetime.now()
        user_info["password"] = hash_password(user_info["password"])
        mycol.insert_one(user_info)

        current_app.logger.info(f"User with uuid {user_uuid} and username {user_info["username"]} registered successfully")

        return jsonify(message="User registered successfully", uuid=user_uuid), 201

    def get_auth(self, username):

        mycol = self.db.get_col_by_name(self.db.capif_users)

        try:

            exist_user = mycol.find_one({"username": username})

            if exist_user is None:
                current_app.logger.warning(f"No user exists with these credentials: {username}")
                return jsonify("No user exists with these credentials"), 400

            access_token = create_access_token(identity=(username + " " + exist_user["uuid"]))
            # TODO: should we remove this log to avoid logging access/refresh tokens?
            current_app.logger.debug(f"Access token generated for user {username} : {access_token}")
            
            cert_file = open("certs/ca_root.crt", 'rb')
            ca_root = cert_file.read()
            cert_file.close()

            current_app.logger.debug(f"Returning the requested information...")

            return jsonify(message="Token and CA root returned successfully", 
                            access_token=access_token, 
                            ca_root=ca_root.decode("utf-8"),
                            ccf_api_onboarding_url="api-provider-management/v1/registrations",
                            ccf_publish_url="published-apis/v1/<apfId>/service-apis",
                            ccf_onboarding_url="api-invoker-management/v1/onboardedInvokers",
                            ccf_discover_url="service-apis/v1/allServiceAPIs?api-invoker-id=",
                            ccf_security_url="capif-security/v1/trustedInvokers/<apiInvokerId>"), 200

        except Exception as e:
            # TODO: consider logging exceptions here for troubleshooting.
            # Example: current_app.logger.exception(f"Unexpected error in get_auth for user {username}")
            return jsonify(message=f"Errors when try getting auth: {e}"), 500

    def remove_user(self, uuid):
        mycol = self.db.get_col_by_name(self.db.capif_users)

        try:
            current_app.logger.debug(f"Request Helper service to remove user related information")
            url = f"https://{self.config["ccf"]["url"]}{self.config["ccf"]["helper_remove_user"]}{uuid}"
            current_app.logger.debug(f"Url {url}")
            requests.delete(url, cert=("certs/superadmin.crt", "certs/superadmin.key"), verify="certs/ca_root.crt", timeout=int(os.getenv("TIMEOUT", "30")))
            
            current_app.logger.debug(f"Removing User with uuid {uuid} from db")
            mycol.delete_one({"uuid": uuid})
            current_app.logger.info(f"User with uuid {uuid} removed successfully")
            return jsonify(message="User removed successfully"), 204
        except Exception as e:
            # TODO: consider logging exceptions here for troubleshooting.
            # Example: current_app.logger.exception(f"Unexpected error in remove_user for uuid {uuid}")
            return jsonify(message=f"Errors when try remove user: {e}"), 500
        
    def get_users(self):
        mycol = self.db.get_col_by_name(self.db.capif_users)

        try:
            # TODO: consider excluding sensitive fields (e.g. password) from logged user info even in debug mode.
            current_app.logger.debug(f"users")
            users=list(mycol.find({}, {"_id":0}))
            current_app.logger.debug(f"{users}")
            return jsonify(message="Users successfully obtained", users=users), 200
        except Exception as e:
            # TODO: consider logging exceptions here for troubleshooting.
            # Example: current_app.logger.exception(f"Unexpected error in get_users")
            return jsonify(message=f"Error trying to get users: {e}"), 500


    def get_register_configuration(self):
        """Retrieve the current register configuration from MongoDB"""
        current_app.logger.debug("Retrieving register configuration")
        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        config = config_col.find_one({}, {"_id": 0})

        if not config:
            return jsonify(message="No register configuration found"), 404

        return jsonify(config), 200

    def update_register_config_param(self, param_path, new_value):
        """Update a specific parameter in the register configuration"""
        current_app.logger.debug(f"Updating register configuration parameter: {param_path} with value: {new_value}")
        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        update_query = {"$set": {param_path: new_value}}
        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path}' not updated"), 404

        return jsonify(message=f"Parameter '{param_path}' updated successfully"), 200

    def replace_register_configuration(self, new_config):
        """Replace the entire register configuration"""
        current_app.logger.debug("Replacing entire register configuration")

        error_response = validate_snake_case_keys(new_config)
        if error_response:
            return error_response

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        result = config_col.replace_one({}, new_config, upsert=True)

        if result.matched_count == 0:
            return jsonify(message="No existing configuration found; a new one was created"), 201

        return jsonify(message="Register configuration replaced successfully"), 200
    

    def add_new_category(self, category_name, category_values):
        """Adds a new category of parameters in 'settings'."""
        current_app.logger.debug(f"Adding new category: {category_name} with values: {category_values}")
        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        
        category_name_snake = to_snake_case(category_name)
        category_values_snake = convert_dict_keys_to_snake_case(category_values)

        update_query = {"$set": {f"settings.{category_name_snake}": category_values_snake}}
        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or category '{category_name_snake}' not added"), 404

        return jsonify(message=f"Category '{category_name_snake}' added successfully"), 200


    def add_new_config_setting(self, param_path, new_value):
        """Adds a new parameter inside a category in 'settings'."""
        current_app.logger.debug(f"Adding new configuration setting: {param_path} with value: {new_value}")
        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        
        param_path_snake = ".".join(to_snake_case(part) for part in param_path.split("."))
        update_query = {"$set": {f"settings.{param_path_snake}": new_value}}
        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path_snake}' not updated"), 404

        return jsonify(message=f"Parameter '{param_path_snake}' added successfully"), 200
    

    def remove_register_config_param(self, param_path):
        """
        Removes a specific parameter in the registry settings.
        """
        current_app.logger.debug(f"Removing configuration parameter: {param_path}")
        
        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        
        param_path_snake = ".".join(to_snake_case(part) for part in param_path.split("."))
        update_query = {"$unset": {f"settings.{param_path_snake}": ""}}

        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path_snake}' not removed"), 404

        return jsonify(message=f"Parameter '{param_path_snake}' removed successfully"), 200
    

    def remove_register_config_category(self, category_name):
        """
        Deletes an entire category within 'settings'.
        """
        current_app.logger.debug(f"Removing configuration category: {category_name}")

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        category_name_snake = to_snake_case(category_name)
        update_query = {"$unset": {f"settings.{category_name_snake}": ""}}

        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or category '{category_name_snake}' not removed"), 404

        return jsonify(message=f"Category '{category_name_snake}' removed successfully"), 200


