import re

from flask import jsonify


def to_snake_case(text):
    """
    Convert string to snake case.
    """
    return re.sub(r'\s+', '_', text).lower()

def convert_dict_keys_to_snake_case(data):
    """
    Converts the keys of a dictionary to snake_case.
    """
    if isinstance(data, dict):
        return {to_snake_case(k): convert_dict_keys_to_snake_case(v) for k, v in data.items()}
    return data


def is_snake_case(value):
    """
    Checks if a key is in snake_case.
    """
    return bool(re.match(r'^[a-z0-9_]+$', value))

def validate_snake_case_keys(obj, path="root"):
    """
    Iterates through the JSON validating that all keys are in snake_case.
    """
    for key, value in obj.items():
        if not is_snake_case(key):
            return jsonify({"error": f"The key '{path}.{key}' is not in snake_case"}), 400
        if isinstance(value, dict):
            error_response = validate_snake_case_keys(value, f"{path}.{key}")
            if error_response:
                return error_response
            
def get_nested_value(config, path):
    """
    Gets a value within a nested dictionary by following a path of keys separated by periods.
    """
    keys = path.split('.')
    for key in keys:
        if isinstance(config, dict) and key in config:
            config = config[key]
        else:
            return None
    return config

def convert_value_to_original_type(new_value, current_value):
    """
    Convert new_value to the type of current_value.
    """
    if isinstance(current_value, int):
        try:
            return int(new_value)
        except ValueError:
            return jsonify(message=f"Invalid value: {new_value} is not an integer"), 400
    elif isinstance(current_value, float):
        try:
            return float(new_value)
        except ValueError:
            return jsonify(message=f"Invalid value: {new_value} is not a float"), 400
    elif isinstance(current_value, bool):
        if isinstance(new_value, str) and new_value.lower() in ["true", "false"]:
            return new_value.lower() == "true"
        elif not isinstance(new_value, bool):
            return jsonify(message=f"Invalid value: {new_value} is not a boolean"), 400
    return new_value

def convert_nested_values(new_data, reference_data):
    """
    Recursively traverses new_data and converts values ​​back to the original type based on reference_data.
    """
    if isinstance(new_data, dict) and isinstance(reference_data, dict):
        for key, value in new_data.items():
            if key in reference_data:
                new_data[key] = convert_nested_values(value, reference_data[key])
    elif isinstance(reference_data, int):
        try:
            return int(new_data)
        except ValueError:
            return new_data
    elif isinstance(reference_data, float):
        try:
            return float(new_data)
        except ValueError:
            return new_data
    elif isinstance(reference_data, bool):
        if isinstance(new_data, str) and new_data.lower() in ["true", "false"]:
            return new_data.lower() == "true"
    return new_data