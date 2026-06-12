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
