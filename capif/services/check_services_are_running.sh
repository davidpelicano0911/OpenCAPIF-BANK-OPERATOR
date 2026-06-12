#!/bin/bash
source $(dirname "$(readlink -f "$0")")/variables.sh

export CAPIF_PRIV_KEY=
export CAPIF_PRIV_KEY_BASE_64=

running="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME docker compose -f docker-compose-vault.yml ps --services --all --filter "status=running")"
services="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME docker compose -f docker-compose-vault.yml ps --services --all)"
if [ "$running" != "$services" ]; then
    echo "Following Vault services are not running:"
    # Bash specific
    comm -13 <(sort <<<"$running") <(sort <<<"$services")
    exit 1
else
    echo "All Vault services are running"
fi

running="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME MONITORING=$MONITORING_STATE LOG_LEVEL=$LOG_LEVEL docker compose -f docker-compose-capif.yml ps --services --all --filter "status=running")"
services="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME MONITORING=$MONITORING_STATE LOG_LEVEL=$LOG_LEVEL docker compose -f docker-compose-capif.yml ps --services --all)"
if [ "$running" != "$services" ]; then
    echo "Following CCF services are not running:"
    # Bash specific
    comm -13 <(sort <<<"$running") <(sort <<<"$services")
    exit 1
else
    echo "All CCF services are running"
fi

running="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_PRIV_KEY=$CAPIF_PRIV_KEY_BASE_64 LOG_LEVEL=$LOG_LEVEL docker compose -f docker-compose-register.yml ps --services --all --filter "status=running")"
services="$(REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_PRIV_KEY=$CAPIF_PRIV_KEY_BASE_64 LOG_LEVEL=$LOG_LEVEL docker compose -f docker-compose-register.yml ps --services --all)"
if [ "$running" != "$services" ]; then
    echo "Following Register services are not running:"
    # Bash specific
    comm -13 <(sort <<<"$running") <(sort <<<"$services")
    exit 1
else
    echo "All Register services are running"
fi

exit 0
