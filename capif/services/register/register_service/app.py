
import json
import logging
import os
import time

import requests
from config import Config
from controllers.register_controller import register_routes
from db.db import MongoDatabse
from flask import Flask
from flask_jwt_extended import JWTManager
from OpenSSL.crypto import (FILETYPE_PEM, TYPE_RSA, PKey, X509Req,
                            dump_certificate_request, dump_privatekey)
from utils.auth_utils import hash_password

app = Flask(__name__)


jwt_manager = JWTManager(app)

config = Config().get_config()

# Connect MongoDB and get TTL for superadmin certificate
db = MongoDatabse()
capif_config = db.get_col_by_name("capif_configuration").find_one({})
ttl_superadmin_cert = capif_config.get("settings", {}).get("certificates_expiry", {}).get("ttl_superadmin_cert", "43000h")

# Setting log level
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
numeric_level = getattr(logging, log_level, logging.INFO)

# Create a superadmin CSR and keys
key = PKey()
key.generate_key(TYPE_RSA, 2048)
req = X509Req()
req.get_subject().O = 'Telefonica I+D'
req.get_subject().OU = 'Innovation'
req.get_subject().L = 'Madrid'
req.get_subject().ST = 'Madrid'
req.get_subject().C = 'ES'
req.get_subject().emailAddress = 'inno@tid.es'
req.set_pubkey(key)
req.sign(key, 'sha256')

csr_request = dump_certificate_request(FILETYPE_PEM, req)
private_key = dump_privatekey(FILETYPE_PEM, key)

# Save superadmin private key
key_file = open("certs/superadmin.key", 'wb+')
key_file.write(bytes(private_key))
key_file.close()

# Request superadmin certificate
url = 'http://{}:{}/v1/pki_int/sign/my-ca'.format(config["ca_factory"]["url"], config["ca_factory"]["port"])  
headers = {'X-Vault-Token': f"{config["ca_factory"]["token"]}"}  
data = {
    'format':'pem_bundle',
    'ttl': ttl_superadmin_cert,
    'csr': csr_request,
    'common_name': "superadmin"
}

response = requests.request("POST", url, headers=headers, data=data, verify = config["ca_factory"].get("verify", False))
superadmin_cert = json.loads(response.text)['data']['certificate']

# Save the superadmin certificate
cert_file = open("certs/superadmin.crt", 'wb')
cert_file.write(bytes(superadmin_cert, 'utf-8'))
cert_file.close()

url = f"http://{config['ca_factory']['url']}:{config['ca_factory']['port']}/v1/secret/data/ca"
headers = {

        'X-Vault-Token': config['ca_factory']['token']
}
response = requests.request("GET", url, headers=headers, verify = config["ca_factory"].get("verify", False))

ca_root = json.loads(response.text)['data']['data']['ca']
cert_file = open("certs/ca_root.crt", 'wb')
cert_file.write(bytes(ca_root, 'utf-8'))
cert_file.close()


# ------------------------------------------------------------
# Get CCF_ID from helper (internal docker network)
# ------------------------------------------------------------
helper_url = "http://helper:8080/helper/api/getCcfId"
CCF_ID = None
max_retries = 30
retry_delay = 2

for attempt in range(1, max_retries + 1):
    try:
        ccf_resp = requests.get(helper_url, timeout=5)
        ccf_resp.raise_for_status()
        CCF_ID = ccf_resp.json().get("ccf_id")
        if CCF_ID:
            print(f"[INFO] Got CCF_ID={CCF_ID}")
            break
    except Exception as e:
        print(f"[WARN] Helper not ready (attempt {attempt}/{max_retries}): {e}")

    time.sleep(retry_delay)

if not CCF_ID:
    raise RuntimeError("Helper did not return ccf_id after retries")


url = 'http://{}:{}/v1/secret/data/capif/{}/nginx'.format(config["ca_factory"]["url"], config["ca_factory"]["port"], CCF_ID)
headers = {'X-Vault-Token': f"{config["ca_factory"]["token"]}"}
response = requests.request("GET", url, headers=headers, verify = config["ca_factory"].get("verify", False))
response.raise_for_status()
key_data = json.loads(response.text)["data"]["data"]["server_key"]

# Create an Admin in the Admin Collection
client = MongoDatabse()
admin_username = config["register"]["admin_users"]["admin_user"]
admin_password = config["register"]["admin_users"]["admin_pass"]

if not client.get_col_by_name(client.capif_admins).find_one({"admin_name": admin_username}):
    print(f'Inserting Initial Admin admin_name: {config["register"]["admin_users"]["admin_user"]}')

    client.get_col_by_name(client.capif_admins).insert_one({"admin_name": config["register"]["admin_users"]["admin_user"], "admin_pass": hash_password(config["register"]["admin_users"]["admin_pass"])})


app.config['JWT_ALGORITHM'] = 'RS256'
app.config['JWT_PRIVATE_KEY'] = key_data
app.config['REGISTRE_SECRET_KEY'] = config["register"]["register_uuid"]

app.logger.setLevel(numeric_level)

app.register_blueprint(register_routes)