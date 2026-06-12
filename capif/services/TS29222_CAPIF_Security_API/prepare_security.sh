#!/bin/bash

VAULT_ADDR="http://$VAULT_HOSTNAME:$VAULT_PORT"
VAULT_TOKEN=$VAULT_ACCESS_TOKEN

CERTS_FOLDER="/usr/src/app/capif_security"
# cd $CERTS_FOLDER

# Maximum number of retry attempts
MAX_RETRIES=30
# Delay between retries (in seconds)
RETRY_DELAY=10
# Attempt counter
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_RETRIES ]; do
    # Increment ATTEMPT using eval
    eval "ATTEMPT=\$((ATTEMPT + 1))"
    echo "Attempt $ATTEMPT of $MAX_RETRIES"

    # Make the request to Vault and store the response in a variable
    RESPONSE=$(curl -s -k --connect-timeout 5 --max-time 10 \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        --request GET "$VAULT_ADDR/v1/secret/data/ca" | jq -r '.data.data.ca')

    echo "$RESPONSE"

    # Check if the response is "null" or empty
    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
        echo "$RESPONSE" > $CERTS_FOLDER/ca.crt
        openssl verify -CAfile $CERTS_FOLDER/ca.crt $CERTS_FOLDER/ca.crt
        echo "CA Root successfully saved."
        SUCCES_OPERATION=true
        break
    else
        echo "Invalid response ('null' or empty), retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    fi
done

if [ "$SUCCES_OPERATION" = false ]; then
    echo "Error: Failed to retrieve ca root a valid response after $MAX_RETRIES attempts."
    exit 1  # Exit with failure
fi

# Setup inital value to ATTEMPT and SUCCESS_OPERATION
ATTEMPT=0
SUCCES_OPERATION=false

HELPER_URL="http://helper:8080/helper/api/getCcfId"
ATTEMPT_CCFID=0
CCF_ID=""

while [ $ATTEMPT -lt $MAX_RETRIES ]; do
    # Increment ATTEMPT using eval
    eval "ATTEMPT=\$((ATTEMPT + 1))"
    echo "Attempt $ATTEMPT of $MAX_RETRIES"

    # Get CCF_ID from helper
    echo "[STEP] Fetching CCF_ID from Helper: $HELPER_URL"
    while [ $ATTEMPT_CCFID -lt $MAX_RETRIES ]; do
        ATTEMPT_CCFID=$((ATTEMPT_CCFID + 1))
        echo "[INFO] Attempt $ATTEMPT_CCFID/$MAX_RETRIES – GET $HELPER_URL"

        RAW=$(curl -sS --fail --connect-timeout 5 --max-time 10 "$HELPER_URL" || true)
        CCF_ID=$(echo "$RAW" | jq -r '.ccf_id // empty' 2>/dev/null)

        if [ -n "$CCF_ID" ]; then
            echo "[INFO] Got CCF_ID=$CCF_ID"
            break
        fi

        echo "[WARN] Helper not ready or invalid response. Retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    done

    if [ -z "$CCF_ID" ]; then
        echo "[ERROR] Unable to retrieve CCF_ID from Helper after $MAX_RETRIES attempts"
        exit 1
    fi


    RESPONSE=$(curl -s -k --connect-timeout 5 --max-time 10 \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        --request GET "$VAULT_ADDR/v1/secret/data/capif/${CCF_ID}/nginx" | jq -r '.data.data.server_key')

    echo "$RESPONSE"

    # Check if the response is "null" or empty
    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
        echo "$RESPONSE" > $CERTS_FOLDER/server.key
        echo "Public key successfully saved."
        SUCCES_OPERATION=true
        break
    else
        echo "Invalid response ('null' or empty), retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    fi
done

if [ "$SUCCES_OPERATION" = false ]; then
    echo "Error: Failed to retrieve server key valid response after $MAX_RETRIES attempts."
    exit 1  # Exit with failure
fi

gunicorn -k uvicorn.workers.UvicornH11Worker --bind 0.0.0.0:8080 \
         --chdir $CERTS_FOLDER wsgi:app
