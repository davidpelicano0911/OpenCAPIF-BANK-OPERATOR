#!/usr/bin/env python3

from datetime import datetime, timedelta
from functools import wraps

import jwt
from config import Config
from core.register_operations import RegisterOperations
from db.db import MongoDatabse
from flask import Blueprint, current_app, jsonify, request
from flask_httpauth import HTTPBasicAuth
from utils.auth_utils import check_password

auth = HTTPBasicAuth()

config = Config().get_config()

register_routes = Blueprint("register_routes", __name__)
register_operation = RegisterOperations()

# Function to generate access tokens and refresh tokens
def generate_tokens(username):
    current_app.logger.debug(f"generating admin tokens...")
    access_payload = {
        'username': username,
        'exp': datetime.now() + timedelta(minutes=config["register"]["token_expiration"])
    }
    refresh_payload = {
        'username': username,
        'exp': datetime.now() + timedelta(days=config["register"]["refresh_expiration"])
    }
    access_token = jwt.encode(access_payload, current_app.config['REGISTRE_SECRET_KEY'], algorithm='HS256')
    refresh_token = jwt.encode(refresh_payload, current_app.config['REGISTRE_SECRET_KEY'], algorithm='HS256')
    # TODO: should we remove this log to avoid logging access/refresh tokens?
    current_app.logger.debug(f"Access token : {access_token}\nRefresh token : {refresh_token}")
    return access_token, refresh_token

# Function in charge of verifying the basic auth
@auth.verify_password
def verify_password(username, password):
    current_app.logger.debug("Checking user credentials...")
    users = register_operation.get_users()[0].json["users"]
    client = MongoDatabse()
    admin = client.get_col_by_name(client.capif_admins).find_one({"admin_name": username})
    if admin and check_password(password, admin["admin_pass"]):
        current_app.logger.info(f"Verified admin {username}")
        return username, "admin"
    for user in users:
        if user["username"] == username and check_password(password, user["password"]):
            current_app.logger.info(f"Verified user {username}")
            return username, "client"


# Function responsible for verifying the token
def admin_required():
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            current_app.logger.debug("Checking admin token...")
            token = request.headers.get('Authorization')
            if not token:
                current_app.logger.warning("Token is missing.")
                return jsonify({'message': 'Token is missing'}), 401
            
            if token.startswith('Bearer '):
                # Token is not missing but provided with the "Bearer " prefix. Consider changing the following message accordingly or remove it.
                current_app.logger.debug("Token is missing.")
                token = token.split('Bearer ')[1]
            
            if not token:
                current_app.logger.warning("Token is missing.")
                return jsonify({'message': 'Token is missing'}), 401

            try:
                data = jwt.decode(token, current_app.config['REGISTRE_SECRET_KEY'], algorithms=['HS256'], options={'verify_exp': True})
                username = data['username']
                return f(username, *args, **kwargs)
            except Exception as e:
                current_app.logger.debug(f"Error: {str(e)}.")
                return jsonify({'message': str(e)}), 401

        return decorated
    return decorator

@register_routes.route('/login', methods=['POST'])
@auth.login_required
def login():
    username, rol = auth.current_user()
    if rol != "admin":
        current_app.logger.warning(f"User {username} trying to log in as admin")
        return jsonify(message="Unauthorized. Administrator privileges required."), 401
    access_token, refresh_token = generate_tokens(username)
    return jsonify({'access_token': access_token, 'refresh_token': refresh_token})

@register_routes.route('/refresh', methods=['POST'])
@admin_required()
def refresh_token(username):
    current_app.logger.debug(f"Refreshing token for admin {username}")
    access_token, _ = generate_tokens(username)
    return jsonify({'access_token': access_token})

@register_routes.route("/createUser", methods=["POST"])
@admin_required()
def register(username):
    current_app.logger.debug(f"Admin {username} creating a user...")
    required_fields = {
        "username": str,
        "password": str,
        "enterprise": str,
        "country": str,
        "email": str,
        "purpose": str
    }

    optional_fields = {
        "phone_number": str,
        "company_web": str,
        "description": str
    }

    user_info = request.get_json()
    # TODO: consider excluding sensitive fields (e.g. password) from logged user info even in debug mode.
    # Example: log_user_info = {k: v for k, v in user_info.items() if k != "password"}
    current_app.logger.debug(f"User Info: {user_info}")
    missing_fields = []
    for field, field_type in required_fields.items():
        if field not in user_info:
            missing_fields.append(field)
        elif not isinstance(user_info[field], field_type):
            current_app.logger.warning(f"Error: Field {field} must be of type {field_type.__name__}")
            return jsonify({"error": f"Field '{field}' must be of type {field_type.__name__}"}), 400

    for field, field_type in optional_fields.items():
        if field in user_info and not isinstance(user_info[field], field_type):
            current_app.logger.warning(f"Error: Field {field} must be of type {field_type.__name__}")
            return jsonify({"error": f"Optional field '{field}' must be of type {field_type.__name__}"}), 400
        if field not in user_info:
            user_info[field] = None

    if missing_fields:
        current_app.logger.warning(f"Error: missing requuired fields : {missing_fields}")
        return jsonify({"error": "Missing required fields", "fields": missing_fields}), 400

    return register_operation.register_user(user_info)

@register_routes.route("/getauth", methods=["GET"])
@auth.login_required
def getauth():
    username, _ = auth.current_user()
    current_app.logger.debug(f"Obtaining authorization for the user {username}")
    return register_operation.get_auth(username)

@register_routes.route("/deleteUser/<uuid>", methods=["DELETE"])
@admin_required()
def remove(username, uuid):
    current_app.logger.debug(f"Deleting user with id {uuid} by admin {username}")
    return register_operation.remove_user(uuid)


@register_routes.route("/getUsers", methods=["GET"])
@admin_required()
def getUsers(username):
    current_app.logger.debug(f"Returning list of users to admin {username}")
    return register_operation.get_users()


@register_routes.route("/configuration", methods=["GET"])
@admin_required()
def get_register_configuration(username):
    """Retrieve the current register configuration"""
    current_app.logger.debug(f"Admin {username} is retrieving the register configuration")
    return register_operation.get_register_configuration()


@register_routes.route("/configuration", methods=["PATCH"])
@admin_required()
def update_register_config_param(username):
    """Update a single parameter in the register configuration"""
    data = request.json
    param_path = data.get("param_path") 
    new_value = data.get("new_value")

    if not param_path or new_value is None:
        return jsonify(message="Missing 'param_path' or 'new_value' in request body"), 400

    current_app.logger.debug(f"Admin {username} is updating parameter {param_path} with value {new_value}")
    return register_operation.update_register_config_param(param_path, new_value)


@register_routes.route("/configuration", methods=["PUT"])
@admin_required()
def replace_register_configuration(username):
    """Replace the entire register configuration"""
    new_config = request.json
    if not new_config:
        return jsonify(message="Missing new configuration in request body"), 400

    current_app.logger.debug(f"Admin {username} is replacing the entire register configuration")
    return register_operation.replace_register_configuration(new_config)


@register_routes.route("/configuration/addNewCategory", methods=["POST"])
def add_new_category():
    """Adds a new category inside 'settings'."""
    data = request.json
    category_name = data.get("category_name")
    category_values = data.get("category_values")

    if not category_name or not category_values:
        return jsonify(message="Missing 'category_name' or 'category_values' in request body"), 400

    return register_operation.add_new_category(category_name, category_values)


@register_routes.route("/configuration/addNewParamConfigSetting", methods=["PATCH"])
def add_new_config_setting():
    """Adds a new configuration inside a category in 'settings'."""
    data = request.json
    param_path = data.get("param_path")
    new_value = data.get("new_value")
    
    if not param_path or new_value is None:
        return jsonify(message="Missing 'param_path' or 'new_value' in request body"), 400
    
    return register_operation.add_new_config_setting(param_path, new_value)


@register_routes.route("/configuration/removeConfigParam", methods=["DELETE"])
@admin_required()
def remove_register_config_param(username):
    """Remove a specific parameter in the register configuration"""
    data = request.json
    param_path = data.get("param_path")

    if not param_path:
        return jsonify(message="Missing 'param_path' in request body"), 400

    current_app.logger.debug(f"Admin {username} is removing parameter {param_path}")
    return register_operation.remove_register_config_param(param_path)


@register_routes.route("/configuration/removeConfigCategory", methods=["DELETE"])
@admin_required()
def remove_register_config_category(username):
    """Remove an entire category in the register configuration"""
    data = request.json
    category_name = data.get("category_name")

    if not category_name:
        return jsonify(message="Missing 'category_name' in request body"), 400

    current_app.logger.debug(f"Admin {username} is removing category {category_name}")
    return register_operation.remove_register_config_category(category_name)

