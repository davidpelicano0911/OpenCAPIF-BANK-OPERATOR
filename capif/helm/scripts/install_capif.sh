#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

helm repo add grafana https://grafana.github.io/helm-charts
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

"$(dirname "$0")/00_install_capif_monitoring.sh" "$ENVIRONMENT" || { echo "00_install_capif_monitoring.sh failed, exiting"; exit 1; }
"$(dirname "$0")/01_install_capif_db.sh" "$ENVIRONMENT" || { echo "01_install_capif_db.sh failed, exiting"; exit 1; }
"$(dirname "$0")/02_install_capif_db_express.sh" "$ENVIRONMENT" || { echo "02_install_capif_db_express.sh failed, exiting"; exit 1; }
"$(dirname "$0")/03_install_capif_commons.sh" "$ENVIRONMENT" || { echo "03_install_capif_commons.sh failed, exiting"; exit 1; }
"$(dirname "$0")/04_install_capif_services.sh" "$ENVIRONMENT" || { echo "04_install_capif_services.sh failed, exiting"; exit 1; }
"$(dirname "$0")/05_install_capif_register.sh" "$ENVIRONMENT" || { echo "05_install_capif_register.sh failed, exiting"; exit 1; }
