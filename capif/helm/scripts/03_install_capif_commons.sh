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

HELM_STEP_DIR="$HELM_DIR/03_capif_commons"

# Update appVersion
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_03=("celery-beat" "celery-worker" "mock-server" "redis")
for chart in "${charts_03[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_COMMONS

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set mock-server.enabled=true \
    --set mock-server.image.repository=$CAPIF_DOCKER_REGISTRY/mock-server \
    --set mock-server.image.tag=$CAPIF_IMAGE_TAG \
    --set mock-server.ingress.enabled=true \
    --set mock-server.ingress.hosts[0].host=mock-server-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN \
    --set mock-server.ingress.hosts[0].paths[0].path="/" \
    --set mock-server.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set mock-server.env.logLevel="$LOG_LEVEL" \
    --set mock-server.service.port=$MOCK_SERVER_PORT \
    --set mock-server.livenessProbe.tcpSocket.port=$MOCK_SERVER_PORT \
    --set redis.image.repository=$BASE_DOCKER_REGISTRY/redis \
    --set redis.image.tag=7.4.2-alpine \
    --set celery-beat.image.repository=$CAPIF_DOCKER_REGISTRY/celery \
    --set celery-beat.image.tag=$CAPIF_IMAGE_TAG \
    --set celery-beat.env.celeryModel=beat \
    --set celery-beat.env.redisHost=redis \
    --set celery-beat.env.redisPort=6379 \
    --set celery-beat.env.logLevel="$LOG_LEVEL" \
    --set celery-worker.image.repository=$CAPIF_DOCKER_REGISTRY/celery \
    --set celery-worker.image.tag=$CAPIF_IMAGE_TAG \
    --set celery-worker.env.celeryModel=worker \
    --set celery-worker.env.redisHost=redis \
    --set celery-worker.env.redisPort=6379 \
    --set celery-worker.env.logLevel="$LOG_LEVEL" \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE