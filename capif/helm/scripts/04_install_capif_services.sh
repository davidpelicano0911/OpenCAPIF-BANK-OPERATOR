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

HELM_STEP_DIR="$HELM_DIR/04_capif_services"

# Update appVersion
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_04=("nginx" "ocf-access-control-policy" "ocf-api-invocation-logs" "ocf-api-invoker-management" "ocf-api-provider-management" "ocf-auditing-api-logs" "ocf-discover-service-api" "ocf-events" "ocf-helper" "ocf-publish-service-api" "ocf-routing-info" "ocf-security" "ocf-open-discover-service-api")
for chart in "${charts_04[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_SVC

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set ocf-access-control-policy.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-access-control-policy-api \
    --set ocf-access-control-policy.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-access-control-policy.image.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-access-control-policy.monitoring="true" \
    --set ocf-access-control-policy.env.logLevel="$LOG_LEVEL" \
    --set ocf-api-invocation-logs.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-logging-api-invocation-api \
    --set ocf-api-invocation-logs.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-api-invocation-logs.env.monitoring="true" \
    --set ocf-api-invocation-logs.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-api-invocation-logs.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-api-invocation-logs.env.vaultPort=$VAULT_PORT \
    --set ocf-api-invocation-logs.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-api-invocation-logs.env.logLevel="$LOG_LEVEL" \
    --set ocf-api-invoker-management.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-api-invoker-management-api \
    --set ocf-api-invoker-management.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-api-invoker-management.env.monitoring="true" \
    --set ocf-api-invoker-management.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-api-invoker-management.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-api-invoker-management.env.vaultPort=$VAULT_PORT \
    --set ocf-api-invoker-management.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-api-invoker-management.env.logLevel="$LOG_LEVEL" \
    --set ocf-api-provider-management.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-api-provider-management-api \
    --set ocf-api-provider-management.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-api-provider-management.env.monitoring="true" \
    --set ocf-api-provider-management.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-api-provider-management.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-api-provider-management.env.logLevel="$LOG_LEVEL" \
    --set ocf-api-provider-management.env.vaultPort=$VAULT_PORT \
    --set ocf-api-provider-management.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-events.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-events-api \
    --set ocf-events.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-events.env.monitoring="true" \
    --set ocf-events.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-events.env.logLevel="$LOG_LEVEL" \
    --set ocf-routing-info.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-routing-info-api \
    --set ocf-routing-info.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-routing-info.env.monitoring="true" \
    --set ocf-routing-info.env.logLevel="$LOG_LEVEL" \
    --set ocf-security.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-security-api \
    --set ocf-security.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-security.env.monitoring="true" \
    --set ocf-security.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-security.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-security.env.vaultPort=$VAULT_PORT \
    --set ocf-security.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-security.env.logLevel="$LOG_LEVEL" \
    --set ocf-auditing-api-logs.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-auditing-api \
    --set ocf-auditing-api-logs.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-auditing-api-logs.env.monitoring="true" \
    --set ocf-auditing-api-logs.env.logLevel="$LOG_LEVEL" \
    --set ocf-publish-service-api.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-publish-service-api \
    --set ocf-publish-service-api.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-publish-service-api.env.monitoring="true" \
    --set ocf-publish-service-api.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-publish-service-api.env.logLevel="$LOG_LEVEL" \
    --set ocf-discover-service-api.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-discover-service-api \
    --set ocf-discover-service-api.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-discover-service-api.env.monitoring="true" \
    --set ocf-discover-service-api.env.logLevel="$LOG_LEVEL" \
    --set ocf-open-discover-service-api.image.repository=$CAPIF_DOCKER_REGISTRY/ocf-open-discover-service-api \
    --set ocf-open-discover-service-api.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-open-discover-service-api.env.monitoring="true" \
    --set ocf-open-discover-service-api.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-open-discover-service-api.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-open-discover-service-api.env.vaultPort=$VAULT_PORT \
    --set ocf-open-discover-service-api.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-open-discover-service-api.env.logLevel="$LOG_LEVEL" \
    --set ocf-helper.image.repository=$CAPIF_DOCKER_REGISTRY/helper \
    --set ocf-helper.image.tag=$CAPIF_IMAGE_TAG \
    --set ocf-helper.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set ocf-helper.env.vaultPort=$VAULT_PORT \
    --set ocf-helper.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set ocf-helper.env.capifHostname=$CAPIF_HOSTNAME \
    --set ocf-helper.env.logLevel="$LOG_LEVEL" \
    --set nginx.image.repository=$CAPIF_DOCKER_REGISTRY/nginx \
    --set nginx.image.tag=$CAPIF_IMAGE_TAG \
    --set nginx.env.capifHostname=$CAPIF_HOSTNAME \
    --set nginx.env.vaultHostname=$VAULT_INTERNAL_HOSTNAME \
    --set nginx.env.vaultPort=$VAULT_PORT \
    --set nginx.env.vaultAccessToken=$VAULT_ACCESS_TOKEN \
    --set nginx.ingress.enabled=true \
    --set nginx.ingress.hosts[0].host=$CAPIF_HOSTNAME \
    --set nginx.ingress.hosts[0].paths[0].path="/" \
    --set nginx.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set nginx.env.logLevel="$LOG_LEVEL" \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE
