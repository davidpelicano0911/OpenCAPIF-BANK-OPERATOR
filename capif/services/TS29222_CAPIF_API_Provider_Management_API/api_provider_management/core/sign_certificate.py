import json

import requests

from ..config import Config
from ..db.db import MongoDatabse


def sign_certificate(publick_key, provider_id):

    config =  Config().get_config()

    db = MongoDatabse()
    capif_config = db.get_col_by_name("capif_configuration").find_one({"config_name": "default"})
    ttl_provider_cert = capif_config.get("settings", {}).get("certificates_expiry", {}).get("ttl_provider_cert", "4300h")

    url = f"http://{config['ca_factory']['url']}:{config['ca_factory']['port']}/v1/pki_int/sign/my-ca"

    headers = {'X-Vault-Token': config['ca_factory']['token']}
    data = {
        'format':'pem_bundle',
        'ttl': ttl_provider_cert,
        'csr': publick_key,
        'common_name': provider_id
    }

    response = requests.request("POST", url, headers=headers, data=json.dumps(data), verify = config["ca_factory"].get("verify", False))
    response_payload = json.loads(response.text)

    if "errors" in response_payload:
        error_msg = "; ".join(response_payload["errors"])
        raise Exception(f"Certificate signing failed: {error_msg}")
    
    if "data" not in response_payload or "certificate" not in response_payload["data"]:
        raise Exception("Vault response missing certificate data")

    return response_payload["data"]["certificate"]