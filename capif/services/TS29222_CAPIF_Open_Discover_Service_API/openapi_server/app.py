#!/usr/bin/env python3

import json

import connexion
import encoder
from connexion.decorators import parameter as connexion_parameter
from flask_jwt_extended import JWTManager


_original_get_val_from_param = connexion_parameter._get_val_from_param


def _get_val_from_content_param(value, param_defn):
    if "content" not in param_defn or "schema" in param_defn:
        return _original_get_val_from_param(value, param_defn)

    content = param_defn.get("content", {})
    if "application/json" not in content or not isinstance(value, str):
        return value

    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return value


connexion_parameter._get_val_from_param = _get_val_from_content_param

with open("/usr/src/app/openapi_server/pubkey.pem", "rb") as pub_file:
    pub_data = pub_file.read()

app = connexion.App(__name__, specification_dir="openapi/")
app.app.json_encoder = encoder.CustomJSONEncoder
app.add_api(
    "openapi.yaml",
    arguments={"title": "CAPIF_Open_Discover_Service_API"},
    pythonic_params=True,
)

app.app.config["JWT_ALGORITHM"] = "RS256"
app.app.config["JWT_PUBLIC_KEY"] = pub_data

JWTManager(app.app)
