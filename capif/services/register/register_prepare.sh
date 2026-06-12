#!/bin/bash
CERTS_FOLDER="/usr/src/app/register_service/certs"
cd $CERTS_FOLDER

# === CONFIGURATION ===
VAULT_ADDR="http://$VAULT_HOSTNAME:$VAULT_PORT"
VAULT_TOKEN=$VAULT_ACCESS_TOKEN

COUNTRY="ES"             # 2 letter country-code
STATE="Madrid"           # state or province name
LOCALITY="Madrid"        # Locality Name (e.g. city) 
ORGNAME="Telefonica I+D" # Organization Name (eg, company) 
ORGUNIT="Innovation"     # Organizational Unit Name (eg. section) 
COMMONNAME=${REGISTER_HOSTNAME:-register} 
EMAIL="inno@tid.es"     # certificate's email address 
TTL="4300h"

# ==============================================================
# 1) GENERATE PRIVATE KEY IF NOT EXISTS
# ==============================================================

if [ ! -f register_key.key ]; then
  echo "Generating private key for Register."
  openssl genrsa -out register_key.key 2048
else
  echo "register_key.key already exists. Skipping generation."
fi

# ==============================================================
# 2) GENERATE CSR
# ==============================================================

echo "Creating CSR for CN=${COMMONNAME}."
openssl req -new -key register_key.key \
  -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGNAME}/OU=${ORGUNIT}/CN=${COMMONNAME}/emailAddress=${EMAIL}" \
  -addext "subjectAltName=DNS:${COMMONNAME}" \
  -out register.csr

# ==============================================================
# 3) DOWNLOAD CA FROM VAULT
# ==============================================================

echo "Downloading CA chain from Vault."
curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/secret/data/ca" | jq -r '.data.data.ca' > ca_root.crt
 
if [ ! -s ca_root.crt ]; then
  echo "ERROR: could not retrieve CA from Vault."
  exit 1
fi

echo "CA chain retrieved successfully."

echo "CA certificate content:"
echo "-----------------------------------"
cat ca_root.crt
echo "-----------------------------------"


# ==============================================================
# 4) REQUEST SIGNATURE
# ==============================================================

echo "Requesting certificate signature from Vault..."
CSR_CONTENT=$(awk '{printf "%s\\n", $0}' register.csr)

curl -s -X POST \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -d "{\"csr\": \"${CSR_CONTENT}\", \"common_name\": \"${COMMONNAME}\", \"format\": \"pem_bundle\", \"ttl\": \"${TTL}\"}" \
  "${VAULT_ADDR}/v1/pki_int/sign/my-ca" \
  | jq -r '.data.certificate' | awk '{gsub("\\\\n","\n")}1' > register_cert.crt

if [ ! -s register_cert.crt ]; then
  echo "ERROR: could not retrieve signed certificate from Vault."
  exit 1
fi

echo "Certificate signed successfully by Vault intermediate CA."

# ==============================================================
# 5) VERIFY CERTIFICATE CHAIN
# ==============================================================

echo "Verifying certificate chain."
openssl verify -CAfile ca_root.crt register_cert.crt || {
  echo "WARNING: certificate verification failed"
}

# ==============================================================
# 7) START REGISTER SERVICE
# ==============================================================

echo "Starting Register service with signed certificate."
gunicorn --certfile=/usr/src/app/register_service/certs/register_cert.crt \
         --keyfile=/usr/src/app/register_service/certs/register_key.key \
         --ca-certs=/usr/src/app/register_service/certs/ca_root.crt \
         --bind 0.0.0.0:8080 \
         --chdir /usr/src/app/register_service wsgi:app