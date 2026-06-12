#!/bin/sh

# Setup environment variables for Vault
export VAULT_ADDR="http://$VAULT_DEV_LISTEN_ADDRESS"
export VAULT_TOKEN=$VAULT_DEV_ROOT_TOKEN_ID
CAPIF_HOSTNAME="${CAPIF_HOSTNAME:-capifcore}"

echo "CAPIF_HOSTNAME: $CAPIF_HOSTNAME"
echo "VAULT_ADDR: $VAULT_ADDR"
echo "VAULT_TOKEN: $VAULT_TOKEN"

# Enable PKI secrets engine, default path is pki/
vault secrets enable pki


############################################################
# 1) ROOT CA
############################################################

# Modify pki engine settings
vault secrets tune -max-lease-ttl=87600h pki

# Create a root CA with a common name of "capif" and an issuer name of "root-2026". The certificate will be valid for 87600 hours (10 years).
# pki/root/generate/internal => vault generates and store the root CA private key internally and returns the certificate.
vault write -field=certificate \
     pki/root/generate/internal \
     common_name="capif" \
     issuer_name="root-2026" \
     ttl=87600h > root_2026_ca.crt

# Configure the URLs that Vault will include in the issued certificates:
# issuing_certificates: where the CA certificate is published. crl_distribution_points: where the CRL (Certificate Revocation List) is published.
vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"


############################################################
# 2) INTERMEDIATE CA
############################################################

# Enable another PKI engine, but at path pki_int.
vault secrets enable -path=pki_int pki

# Adjust the maximum TTL of the intermediate engine.
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate a CSR for the intermediate CA. This will create a new private key for the intermediate CA and return a CSR that we will sign with the root CA. The CSR is saved in a file called pki_intermediate.csr.
vault write -format=json pki_int/intermediate/generate/internal \
     common_name="capif Intermediate Authority" \
     issuer_name="capif-intermediate" \
    | jq -r '.data.csr' > pki_intermediate.csr

# Sign the intermediate CA with the root CA --> capif_intermediate.cert.pem
vault write -format=json \
     pki/root/sign-intermediate \
     issuer_ref="root-2026" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > capif_intermediate.cert.pem

# vault write pki_int/intermediate/set-signed certificate=@capif_intermediate.cert.pem
vault write pki_int/intermediate/set-signed certificate=@capif_intermediate.cert.pem

############################################################
# 3) CONFIGURE SIGNING ROLE
############################################################

# Creates a role named my-ca within pki_int. This role defines the rules for issuing certificates.
vault write pki_int/roles/my-ca \
     use_csr_common_name=false \
     require_cn=false \
     use_csr_sans=false \
     allow_any_name=true \
     allow_bare_domains=true \
     allow_glob_domains=true \
     allow_subdomains=true \
     max_ttl=4300h

# ============================================================
# 4) CA BUNDLE
# ============================================================

# Save the intermediate and root certificates in a single file (CA bundle) so that nginx can use it as a trust chain.
vault kv put secret/ca ca=@capif_intermediate.cert.pem

echo "[INFO] CA bundle stored at secret/ca"


# ============================================================
# OPTIONAL: Create read-only token for CA access
# ============================================================

# variables for creating a read-only policy and token for the CA
POLICY_NAME="my-policy"
POLICY_FILE="my-policy.hcl"
TOKEN_ID="read-ca-token"

# Create a HCL file with the read-only policy for the CA
echo "path \"secret/data/ca\" {
  capabilities = [\"read\"]
}" > "$POLICY_FILE"

vault policy write "$POLICY_NAME" "$POLICY_FILE"

# Create a token with the policy
TOKEN=$(vault token create -id="$TOKEN_ID" -policy="$POLICY_NAME" -format=json | jq -r '.auth.client_token')

echo "Generated Token:"
echo "$TOKEN"