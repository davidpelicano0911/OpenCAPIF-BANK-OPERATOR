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

HELM_STEP_DIR="$HELM_DIR/05_capif_register"

# Update appVersion
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_05=("ocf-register")
for chart in "${charts_05[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_REGISTER

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set ocf-register.image.repository=$CAPIF_DOCKER_REGISTRY/register \
    --set ocf-register.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-register.env.registerHostname=$REGISTER_HOSTNAME \
    --set ocf-register.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-register.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-register.env.vaultPort=$VAULT_PORT \
    --set ocf-register.env.mongoHost=mongo-register \
    --set ocf-register.env.mongoPort=27017 \
    --set ocf-register.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-register.ingress.enabled=true \
    --set ocf-register.ingress.hosts[0].host=$REGISTER_HOSTNAME \
    --set ocf-register.ingress.hosts[0].paths[0].path="/" \
    --set ocf-register.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set ocf-register.env.logLevel="$LOG_LEVEL" \
    --set ocf-register.extraConfigPod.hostAliases[0].hostnames[0]=$CAPIF_HOSTNAME \
    --set ocf-register.extraConfigPod.hostAliases[0].ip=$K8S_IP \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE
