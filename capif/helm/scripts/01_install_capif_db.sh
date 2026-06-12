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

HELM_STEP_DIR="$HELM_DIR/01_capif_db"

# Update appVersion
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_01=("mongo" "mongo-register")
for chart in "${charts_01[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_DB

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set mongo-register.image.repository=$BASE_DOCKER_REGISTRY/mongo \
    --set mongo-register.image.tag=6.0.2 \
    --set mongo-register.persistence.storageClass=$CAPIF_STORAGE_CLASS \
    --set mongo-register.persistence.storage=$CAPIF_MONGO_REGISTER_STORAGE_SIZE \
    --set mongo-register.extraFlags[0]="--repair" \
    --set mongo-register.env.mongoInitdbRootPassword="$MONGO_DB_REGISTER_ADMIN_PASSWORD" \
    --set mongo-register.env.mongoInitdbRootUsername="$MONGO_DB_REGISTER_ADMIN_USER" \
    --set mongo.persistence.storageClass=$CAPIF_STORAGE_CLASS \
    --set mongo.persistence.storage=$CAPIF_MONGO_STORAGE_SIZE \
    --set mongo.extraFlags[0]="--repair" \
    --set mongo.image.repository=$BASE_DOCKER_REGISTRY/mongo \
    --set mongo.image.tag=6.0.2 \
    --set mongo.busybox.repository=$BASE_DOCKER_REGISTRY/busybox \
    --set mongo.busybox.tag=1.37.0 \
    --set mongo.env.mongoInitdbRootPassword="$MONGO_DB_ADMIN_PASSWORD" \
    --set mongo.env.mongoInitdbRootUsername="$MONGO_DB_ADMIN_USER" \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE