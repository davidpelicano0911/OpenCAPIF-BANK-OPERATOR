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

HELM_STEP_DIR="$HELM_DIR/00_capif_monitoring"

# Update appVersion
ls -rtt $HELM_STEP_DIR
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_00=("fluentbit" "grafana" "loki" "otelcollector" "renderer")
for chart in "${charts_00[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_MONITORING

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set grafana.enabled=$CAPIF_GRAFANA_ENABLED \
    --set grafana.ingress.enabled=true \
    --set grafana.ingress.hosts[0].host=ocf-mon-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN \
    --set grafana.ingress.hosts[0].paths[0].path="/" \
    --set grafana.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set grafana.env.prometheusUrl=$PROMETHEUS_URL \
    --set grafana.env.tempoUrl="http://$RELEASE-tempo:3100" \
    --set grafana.persistence.storageClass=$CAPIF_STORAGE_CLASS \
    --set grafana.persistence.storage=$CAPIF_GRAFANA_STORAGE_SIZE \
    --set fluentbit.enabled=$CAPIF_FLUENTBIT_ENABLED \
    --set loki.enabled=$CAPIF_LOKI_ENABLED \
    --set loki.persistence.storageClass=$CAPIF_STORAGE_CLASS \
    --set loki.persistence.storage=$CAPIF_LOKI_STORAGE_SIZE \
    --set tempo.enabled=$CAPIF_TEMPO_ENABLED \
    --set tempo.tempo.metricsGenerator.remoteWriteUrl=$PROMETHEUS_URL/api/v1/write \
    --set tempo.persistence.size=$CAPIF_TEMPO_STORAGE_SIZE \
    --set otelcollector.enabled=$CAPIF_OTELCOLLECTOR_ENABLED \
    --set otelcollector.configMap.tempoEndpoint=$RELEASE-tempo:4317 \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE
