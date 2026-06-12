import json
import logging
import os
import sys
from pathlib import Path

import connexion
import requests
from asgiref.wsgi import WsgiToAsgi
from config import Config
from db.db import get_mongo
from flask import Flask
from OpenSSL.crypto import (FILETYPE_PEM, TYPE_RSA, PKey, X509Req,
                            dump_certificate_request, dump_privatekey)

# --- Paths setup: make 'services' discoverable so "import api..." works ---
BASE_DIR = Path(__file__).resolve().parent
SERVICES_DIR = BASE_DIR / "services"

# Insert services directory at front of sys.path
if SERVICES_DIR.is_dir():
    services_path_str = str(SERVICES_DIR)
    if services_path_str not in sys.path:
        sys.path.insert(0, services_path_str)
else:
    raise RuntimeError(f"Services directory not found at {SERVICES_DIR!s}")

app = connexion.App(__name__, specification_dir=str(SERVICES_DIR))
config = Config().get_config()

# Connect MongoDB and get TTL for superadmin certificate
db = get_mongo()
capif_config = db.get_col_by_name("capif_configuration").find_one({})
ttl_superadmin_cert = capif_config["settings"]["certificates_expiry"].get("ttl_superadmin_cert", "43000h")

# Setting log level
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
numeric_level = getattr(logging, log_level, logging.INFO)
logging.basicConfig(level=numeric_level)
logger = logging.getLogger(__name__)

# Create a superadmin CSR and keys
key = PKey()
key.generate_key(TYPE_RSA, 2048)
req = X509Req()
req.get_subject().O = 'OCF helper'
req.get_subject().OU = 'helper'
req.get_subject().L = 'Madrid'
req.get_subject().ST = 'Madrid'
req.get_subject().C = 'ES'
req.get_subject().emailAddress = 'helper@tid.es'
req.set_pubkey(key)
req.sign(key, 'sha256')

csr_request = dump_certificate_request(FILETYPE_PEM, req)
private_key = dump_privatekey(FILETYPE_PEM, key)

# Save superadmin private key
CERTS_DIR = Path(__file__).resolve().parent / "certs"

try:
    # If it exists but it's not a directory -> fail early with a clear error
    if CERTS_DIR.exists() and not CERTS_DIR.is_dir():
        raise RuntimeError(f"'certs' exists but is not a directory: {CERTS_DIR}")

    CERTS_DIR.mkdir(parents=True, exist_ok=True)

    # Quick sanity check: can we write there?
    if not os.access(CERTS_DIR, os.W_OK):
        raise PermissionError(f"No write permission on certs dir: {CERTS_DIR}")

    key_path = CERTS_DIR / "superadmin.key"
    with open(key_path, "wb") as f:
        f.write(private_key)

    # Restrict permissions (best-effort; may be limited by FS/umask)
    try:
        os.chmod(key_path, 0o600)
    except Exception as e:
        logger.warning(f"Could not chmod {key_path} to 600: {e}")

    logger.info(f"Superadmin key written to {key_path}")

except Exception:
    logger.exception(f"Failed to write superadmin key under {CERTS_DIR}")
    raise


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
logger.info(f"Superadmin Cert:\n{superadmin_cert}")

# Save the superadmin certificate
with open(CERTS_DIR / "superadmin.crt", "wb") as cert_file:
    cert_file.write(superadmin_cert.encode("utf-8"))

url = f"http://{config['ca_factory']['url']}:{config['ca_factory']['port']}/v1/secret/data/ca"
headers = {

        'X-Vault-Token': config['ca_factory']['token']
}
response = requests.request("GET", url, headers=headers, verify = config["ca_factory"].get("verify", False))

ca_root = json.loads(response.text)['data']['data']['ca']
logger.info(f"CA root:\n{ca_root}")
with open(CERTS_DIR / "ca_root.crt", "wb") as cert_file:
    cert_file.write(ca_root.encode("utf-8"))


package_paths = config.get("package_paths", {})

if not package_paths:
    logger.error("No package paths defined in configuration.")
    raise Exception("No package paths defined in configuration.")

# Dynamically add all APIs defined in package_paths
for name, pkg in package_paths.items():
    openapi_file = pkg.get("openapi_file")
    base_path = pkg.get("path")

    if not openapi_file or not base_path:
        logger.warning(f"Skipping package_path '{name}' because 'openapi_file' or 'path' is missing.")
        continue

    # Build a readable title from the key, e.g. "helper_api" -> "Helper Api"
    title = name.replace("_", " ").title()

    logger.info(
        f"Adding API '{name}': openapi_file='{openapi_file}', base_path='{base_path}', title='{title}'"
    )

    app.add_api(
        openapi_file,             # relative to specification_dir (SERVICES_DIR)
        arguments={"title": title},
        pythonic_params=True,
        base_path="/helper/" + base_path
    )


app.app.logger.setLevel(numeric_level)

asgi_app = WsgiToAsgi(app)