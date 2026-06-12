#!/bin/bash
CERTS_FOLDER="/etc/nginx/certs"
cd $CERTS_FOLDER

VAULT_ADDR="http://$VAULT_HOSTNAME:$VAULT_PORT"
VAULT_TOKEN=$VAULT_ACCESS_TOKEN

# Maximum number of retry attempts
MAX_RETRIES=30
# Delay between retries (in seconds)
RETRY_DELAY=10
# Attempt counter
ATTEMPT=0
# Success check
SUCCES_OPERATION=false

# Variable to store CCF_ID retrieved from Helper
CCF_ID=""

fetch_ca_root_cert_from_vault() {
    if [ ! -f $CERTS_FOLDER/ca.crt ]; then
        ###############################################################
        # 1) FETCH CA ROOT CERTIFICATE FROM VAULT
        ###############################################################

        echo "[STEP] Fetching CA root certificate from Vault"
        while [ $ATTEMPT -lt $MAX_RETRIES ]; do
            # Increment ATTEMPT using eval
            eval "ATTEMPT=\$((ATTEMPT + 1))"
            echo "[INFO] Attempt $ATTEMPT/$MAX_RETRIES – GET secret/data/ca"

            # Make the request to Vault and store the response in a variable
            RESPONSE=$(curl -s -k --connect-timeout 5 --max-time 10 \
                --header "X-Vault-Token: $VAULT_TOKEN" \
                --request GET "$VAULT_ADDR/v1/secret/data/ca" | jq -r '.data.data.ca')

            echo "[DEBUG] Raw Vault response:"
            echo "$RESPONSE"

            # Check if the response is "null" or empty
            if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
                echo "$RESPONSE" > $CERTS_FOLDER/ca.crt
                openssl verify -CAfile $CERTS_FOLDER/ca.crt $CERTS_FOLDER/ca.crt
                echo "CA Root successfully saved."
                SUCCES_OPERATION=true
                break
            else
                echo "[ERROR] CA not available yet (null or empty). Retrying in ${RETRY_DELAY}s"
                sleep $RETRY_DELAY
            fi
        done

        if [ "$SUCCES_OPERATION" = false ]; then
            echo "[ERROR] Unable to retrieve CA certificate from Vault after $MAX_RETRIES attempts"
            exit 1
        fi
    else
        echo "CA certificate already exists. Skipping retrieval from Vault."
    fi
}

generate_server_key_if_missing() {
    ###############################################################
    # 2) GENERATE SERVER KEY IF MISSING
    ###############################################################
    if [ ! -f $CERTS_FOLDER/server.key ]; then
        echo "server.key not found. Generating new private key..."
        openssl genrsa -out $CERTS_FOLDER/server.key 2048
    else
        echo "server.key already exists. Skipping generation."
    fi
}


generate_server_key_and_sign() {
    ###############################################################
    # 3) IF NO SERVER CERT → GENERATE CSR + REQUEST SIGNING IN VAULT
    ###############################################################
    if [ ! -f $CERTS_FOLDER/server.crt ]; then
        SUCCESS_OPERATION=false
        
        echo "[STEP 3] Server certificate not found"
        echo "[STEP 3] Generating CSR for CAPIF service"
        echo "[INFO] Common Name (CN): $CAPIF_HOSTNAME"

        # Generate CSR using the previously generated server.key
        openssl req -new -key $CERTS_FOLDER/server.key \
            -subj "/CN=$CAPIF_HOSTNAME" \
            -addext "subjectAltName=DNS:$CAPIF_HOSTNAME" \
            -out $CERTS_FOLDER/server.csr

        # Convert the CSR to a single line with \n so it can be sent in the body of the request to Vault (which expects JSON)
        CSR_CONTENT=$(sed ':a;N;$!ba;s/\n/\\n/g' $CERTS_FOLDER/server.csr)

        echo "[STEP 3] CSR generated successfully"
        echo "[STEP 3] Requesting certificate signing from Vault"
        echo "[INFO] Vault PKI endpoint: $VAULT_ADDR/v1/pki_int/sign/my-ca"

        ATTEMPT=0
        SUCCESS_OPERATION=false

        while [ $ATTEMPT -lt $MAX_RETRIES ]; do
            ATTEMPT=$((ATTEMPT + 1))
            echo "[STEP 3] Attempt $ATTEMPT/$MAX_RETRIES – Signing CSR in Vault"

            # POST /v1/pki_int/sign/my-ca intermediate's endpoint to sign the CSR
            SIGN_RESPONSE=$(curl -s -X POST \
                -H "X-Vault-Token: $VAULT_TOKEN" \
                -d "{\"csr\":\"$CSR_CONTENT\",\"format\":\"pem_bundle\",\"common_name\":\"$CAPIF_HOSTNAME\"}" \
                "$VAULT_ADDR/v1/pki_int/sign/my-ca")

            # SIGN_RESPONSE; return a PEM bundle format with the signed certificate + intermediate certificate chain (but without the root).

            CERT=$(printf '%s' "$SIGN_RESPONSE" | jq -er '.data.certificate')

            if [ -n "$CERT" ] && [ "$CERT" != "null" ]; then
                echo "$CERT" > $CERTS_FOLDER/server.crt
                echo "Server certificate successfully signed and saved."
                SUCCESS_OPERATION=true
                break
            else
                echo "Invalid certificate response. Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        done

        if [ "$SUCCESS_OPERATION" = false ]; then
            echo "[STEP 3][ERROR] Failed to sign server certificate after $MAX_RETRIES attempts"
            exit 1
        fi
    else
        echo "[STEP 3] $CERTS_FOLDER/server.crt already exists – skipping certificate signing"
    fi
}

extract_public_key() {
    if [ ! -f $CERTS_FOLDER/server_pub.pem ]; then
        ###############################################################
        # 4) Extract the public key from server.crt and save it as server_pub.pem
        ###############################################################
        openssl x509 -pubkey -noout -in $CERTS_FOLDER/server.crt > $CERTS_FOLDER/server_pub.pem
    else
        echo "Public key already extracted. Skipping extraction."
    fi
}

get_ccf_id_from_helper() {
    ###############################################################
    # 5) CCF_ID RETRIEVAL (from helper, inside docker network)
    ###############################################################
    HELPER_URL="http://helper:8080/helper/api/getCcfId"
    ATTEMPT_CCFID=0
    

    echo "[STEP] Fetching CCF_ID from Helper: $HELPER_URL"

    # Retry loop to get CCF_ID from Helper
    while [ $ATTEMPT_CCFID -lt $MAX_RETRIES ]; do
    ATTEMPT_CCFID=$((ATTEMPT_CCFID + 1))
    echo "[INFO] Attempt $ATTEMPT_CCFID/$MAX_RETRIES – GET $HELPER_URL"

    RESP=$(curl -s --connect-timeout 5 --max-time 10 "$HELPER_URL" || true)

    CCF_ID=$(printf '%s' "$RESP" | jq -r '.ccf_id // empty' 2>/dev/null || true)

    if [ -n "$CCF_ID" ]; then
        echo "[INFO] Got CCF_ID=$CCF_ID"
        break
    fi

    echo "[WARN] Helper not ready or invalid response: $RESP"
    echo "[WARN] Retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
    done

    if [ -z "$CCF_ID" ]; then
    echo "[ERROR] Unable to retrieve CCF_ID from Helper after $MAX_RETRIES attempts"
    exit 1
    fi
}


store_certs_in_vault() {
    ###############################################################
    # 6) STORE CERTIFICATES IN VAULT UNDER capif/<ccf_id>
    ###############################################################
    echo "Storing CAPIF certificates in Vault..."

    SERVER_CRT_ESCAPED=$(sed ':a;N;$!ba;s/\n/\\n/g' $CERTS_FOLDER/server.crt)
    SERVER_KEY_ESCAPED=$(sed ':a;N;$!ba;s/\n/\\n/g' $CERTS_FOLDER/server.key)
    SERVER_PUB_ESCAPED=$(sed ':a;N;$!ba;s/\n/\\n/g' $CERTS_FOLDER/server_pub.pem)
    CA_ESCAPED=$(sed ':a;N;$!ba;s/\n/\\n/g' $CERTS_FOLDER/ca.crt)

    # Store the server certificate, private key and CA certificate in Vault under secret/data/capif/<ccf_id>/nginx
    VAULT_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/vault_resp.json \
    -X POST \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"data\": {
        \"server_crt\": \"${SERVER_CRT_ESCAPED}\",
        \"server_key\": \"${SERVER_KEY_ESCAPED}\",
        \"server_pub\": \"${SERVER_PUB_ESCAPED}\",
        \"ca\": \"${CA_ESCAPED}\"
        }
    }" \
    "$VAULT_ADDR/v1/secret/data/capif/${CCF_ID}/nginx")

    if [ "$VAULT_RESPONSE" != "200" ] && [ "$VAULT_RESPONSE" != "204" ]; then
    echo "[ERROR] Failed to store certs in Vault"
    cat /tmp/vault_resp.json
    exit 1
    fi

    echo "Certificates successfully stored in Vault namespace: secret/capif/$CCF_ID"
}

check_value_and_store(){
    INPUT_VALUE=$1
    OUTPUT_FILE=$2
    if [ -n "$INPUT_VALUE" ] && [ "$INPUT_VALUE" != "null" ]; then
        echo "$INPUT_VALUE" > $OUTPUT_FILE
        echo "Value successfully saved to $OUTPUT_FILE."
    else
        echo "Invalid value for $OUTPUT_FILE ('null' or empty)."
        exit 1
    fi
}


get_ccf_id_from_helper
echo "Retrieved CCF_ID from Helper: $CCF_ID"

# Make the request to Vault and store the response in a variable

HTTP_STATUS=$(curl -s -k \
  --connect-timeout 5 \
  --max-time 10 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request GET "$VAULT_ADDR/v1/secret/data/capif/${CCF_ID}/nginx" \
  -o $CERTS_FOLDER/response.json \
  -w "%{http_code}")

echo "HTTP STATUS: $HTTP_STATUS"

RESPONSE=$(cat $CERTS_FOLDER/response.json)
if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ] && [ "$HTTP_STATUS" -eq 200 ] ; then
    echo "RESPONSE is valid, proceeding with certificate extraction and storage"
    CA_CERT=$(jq -r '.data.data.ca' $CERTS_FOLDER/response.json)
    SERVER_CRT=$(jq -r '.data.data.server_crt' $CERTS_FOLDER/response.json)
    SERVER_KEY=$(jq -r '.data.data.server_key' $CERTS_FOLDER/response.json)
    SERVER_PUB=$(jq -r '.data.data.server_pub' $CERTS_FOLDER/response.json)

    check_value_and_store "$SERVER_CRT" "$CERTS_FOLDER/server.crt"
    check_value_and_store "$SERVER_KEY" "$CERTS_FOLDER/server.key"
    check_value_and_store "$SERVER_PUB" "$CERTS_FOLDER/server_pub.pem"
    check_value_and_store "$CA_CERT" "$CERTS_FOLDER/ca.crt"

else
    echo "Data not previously stored at Vault. Initialize information"
    fetch_ca_root_cert_from_vault
    generate_server_key_if_missing
    generate_server_key_and_sign
    extract_public_key
    store_certs_in_vault
    echo "Certificate information successfully stored in Vault for CCF_ID=$CCF_ID"
fi


###############################################################
# 7) START NGINX
###############################################################

LOG_LEVEL=$(echo "${LOG_LEVEL}" | tr '[:upper:]' '[:lower:]')

case "$LOG_LEVEL" in
  critical)
    LOG_LEVEL="crit"
    ;;
  fatal)
    LOG_LEVEL="error"
    ;;
  notset)
    LOG_LEVEL="info"
    ;;
esac

echo "Using log level: $LOG_LEVEL"
envsubst '$LOG_LEVEL' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
echo "Saving nginx configuration with log level: $LOG_LEVEL"
nginx
