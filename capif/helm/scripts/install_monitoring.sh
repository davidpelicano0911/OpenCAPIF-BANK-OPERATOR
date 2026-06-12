#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add grafana https://grafana.github.io/helm-charts

helm $KUBECONFIG dependency build $HELM_DIR/monitoring-stack/

helm $KUBECONFIG upgrade --install -n $MONITORING_NAMESPACE $MONITORING_SERVICE_NAME $HELM_DIR/monitoring-stack/ \
--set grafana.enabled=$MONITORING_GRAFANA_ENABLED \
--set grafana.env.prometheusUrl=$PROMETHEUS_URL \
--set grafana.ingress.enabled=true \
--set grafana.ingress.hosts[0].host=$GRAFANA_HOSTNAME \
--set grafana.ingress.hosts[0].paths[0].path="/" \
--set grafana.ingress.hosts[0].paths[0].pathType="Prefix" \
--set prometheus.enabled=$MONITORING_PROMETHEUS_ENABLED \
--set prometheus.ingress.enabled=true \
--set prometheus.ingress.hosts[0].host=$PROMETHEUS_HOSTNAME \
--set prometheus.ingress.hosts[0].paths[0].path="/" \
--set prometheus.ingress.hosts[0].paths[0].pathType="Prefix" \
--set skooner.enabled=$MONITORING_SNOOKER_ENABLED \
--set skooner.ingress.enabled=true \
--set skooner.ingress.hosts[0].host=$SKOONER_HOSTNAME \
--set skooner.ingress.hosts[0].paths[0].path="/" \
--set skooner.ingress.hosts[0].paths[0].pathType="Prefix" \
--wait --timeout=10m --create-namespace --atomic

