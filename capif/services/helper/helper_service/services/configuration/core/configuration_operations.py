
from config import Config
from db.db import get_mongo
from flask import current_app, jsonify
from utils.utils import (convert_dict_keys_to_snake_case,
                         convert_nested_values, convert_value_to_original_type,
                         get_nested_value, to_snake_case,
                         validate_snake_case_keys)


class ConfigurationOperations:

    PROTECTED_FIELDS = ["ccf_id"]

    def __init__(self):
        self.db = get_mongo()
        self.mimetype = 'application/json'
        self.config = Config().get_config()

    def get_configuration(self):
        """Get all current settings."""
        current_app.logger.debug("Retrieving current CAPIF configuration")
        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        config = config_col.find_one({}, {"_id": 0})

        if not config:
            return jsonify(message="No CAPIF configuration found"), 404

        return jsonify(config), 200

    def update_config_param(self, param_path, new_value):
        """
        Updates a single parameter in the configuration.
        param_path: Path of the parameter (e.g., settings.acl_policy_settings.allowed_total_invocations)
        """
        current_app.logger.debug(f"Updating configuration parameter: {param_path} with value: {new_value}")

        # Protect immutable fields
        if any(param_path.startswith(field) for field in self.PROTECTED_FIELDS):
            return jsonify(message=f"The parameter '{param_path}' is immutable and cannot be modified"), 403

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        existing_config = config_col.find_one({}, {"_id": 0})
        current_value = get_nested_value(existing_config, param_path)

        if current_value is None:
            return jsonify(message=f"The parameter '{param_path}' does not exist in the configuration"), 404

        converted_value = convert_value_to_original_type(new_value, current_value)

        if isinstance(converted_value, tuple):
            return converted_value

        update_query = {"$set": {param_path: converted_value}}
        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path}' not updated"), 404

        return jsonify(message=f"Parameter '{param_path}' updated successfully"), 200
    
    
    def replace_configuration(self, new_config):
        current_app.logger.debug("Replacing entire CAPIF configuration")

        error_response = validate_snake_case_keys(new_config)
        if error_response:
            return error_response

        config_col = self.db.get_col_by_name(self.db.capif_configuration)
        existing_config = config_col.find_one({}, {"_id": 0})

        if not existing_config:
            return jsonify(message="No existing configuration found"), 404

        # Preserve protected fields
        for field in self.PROTECTED_FIELDS:
            if field in existing_config:
                new_config[field] = existing_config[field]

        new_config = convert_nested_values(new_config, existing_config)
        result = config_col.replace_one({}, new_config, upsert=True)

        return jsonify(message="Configuration replaced successfully (protected fields preserved)"), 200


    def add_new_configuration(self, category_name, category_values):
        """
        Add a new category of parameters in 'settings'.
        """
        current_app.logger.debug(f"Adding new category: {category_name} with values: {category_values}")

        # Block protected field creation
        if category_name in self.PROTECTED_FIELDS:
            return jsonify(message=f"The category '{category_name}' is immutable and cannot be modified"), 403

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        category_name_snake = to_snake_case(category_name)
        category_values_snake = convert_dict_keys_to_snake_case(category_values)

        update_query = {"$set": {f"settings.{category_name_snake}": category_values_snake}}

        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or category '{category_name_snake}' not added"), 404

        return jsonify(message=f"Category '{category_name_snake}' added successfully"), 200


    def add_new_config_setting(self, param_path, new_value):
        """Add a new parameter in 'settings'."""
        current_app.logger.debug(f"Adding new configuration setting: {param_path} with value: {new_value}")

        # Block protected field creation
        if any(param_path.startswith(field) for field in self.PROTECTED_FIELDS):
            return jsonify(message=f"The parameter '{param_path}' is immutable and cannot be added or modified"), 403
    
        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        param_path_snake = ".".join(to_snake_case(part) for part in param_path.split("."))

        update_query = {"$set": {f"settings.{param_path_snake}": new_value}}
        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path_snake}' not updated"), 404

        return jsonify(message=f"Parameter '{param_path_snake}' added successfully"), 200


    def remove_config_param(self, param_path):
        """Removes a specific parameter inside 'settings'."""
        current_app.logger.debug(f"Removing configuration parameter: {param_path}")

        # Prevent deletion of protected fields
        if any(param_path.startswith(field) for field in self.PROTECTED_FIELDS):
            return jsonify(message=f"The parameter '{param_path}' is immutable and cannot be removed"), 403

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        param_path_snake = ".".join(to_snake_case(part) for part in param_path.split("."))

        update_query = {"$unset": {f"settings.{param_path_snake}": ""}}

        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or parameter '{param_path_snake}' not removed"), 404

        return jsonify(message=f"Parameter '{param_path_snake}' removed successfully"), 200


    def remove_config_category(self, category_name):
        """Removes an entire category inside 'settings'."""
        current_app.logger.debug(f"Removing configuration category: {category_name}")

        # Prevent deletion of protected fields
        if category_name in self.PROTECTED_FIELDS:
            return jsonify(message=f"The category '{category_name}' is immutable and cannot be removed"), 403

        config_col = self.db.get_col_by_name(self.db.capif_configuration)

        category_name_snake = to_snake_case(category_name)

        update_query = {"$unset": {f"settings.{category_name_snake}": ""}}

        result = config_col.update_one({}, update_query)

        if result.modified_count == 0:
            return jsonify(message=f"No configuration found or category '{category_name_snake}' not removed"), 404

        return jsonify(message=f"Category '{category_name_snake}' removed successfully"), 200