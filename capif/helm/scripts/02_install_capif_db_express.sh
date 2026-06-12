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

HELM_STEP_DIR="$HELM_DIR/02_capif_db_express"

# Update appVersion
cat "$HELM_STEP_DIR/Chart.yaml"
yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/Chart.yaml"
cat "$HELM_STEP_DIR/Chart.yaml"
charts_02=("mongo-express" "mongo-register-express")
for chart in "${charts_02[@]}"; do
  yq e -i ".appVersion = \"$CAPIF_IMAGE_TAG\"" "$HELM_STEP_DIR/charts/$chart/Chart.yaml"
done

### download dependencies
helm $KUBECONFIG dependency build $HELM_STEP_DIR/
  
### check ingress_ip.oneke and get ip from ingress-nginx-controller
kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller

RELEASE=$RELEASE_NAME_DB_EXPRESS

install_capif_helm() {
  local extra_args=("$@")
  helm $KUBECONFIG upgrade --install -n $CAPIF_NAMESPACE $RELEASE $HELM_STEP_DIR/ \
    --set mongo-register-express.enabled=true \
    --set mongo-register-express.ingress.enabled=true \
    --set mongo-register-express.ingress.hosts[0].host="mongo-express-register-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN" \
    --set mongo-register-express.ingress.hosts[0].paths[0].path="/" \
    --set mongo-register-express.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set mongo-register-express.env.meConfigMongodbAdminusername="$MONGO_DB_REGISTER_ADMIN_USER" \
    --set mongo-register-express.env.meConfigMongodbAdminpassword="$MONGO_DB_REGISTER_ADMIN_PASSWORD" \
    --set mongo-register-express.env.meConfigMongodbUrl="$MONGO_DB_REGISTER_INTERNAL_URL" \
    --set mongo-express.enabled=true \
    --set mongo-express.ingress.enabled=true \
    --set mongo-express.ingress.hosts[0].host="mongo-express-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN" \
    --set mongo-express.ingress.hosts[0].paths[0].path="/" \
    --set mongo-express.ingress.hosts[0].paths[0].pathType="Prefix" \
    --set mongo-express.env.meConfigMongodbAdminusername="$MONGO_DB_ADMIN_USER" \
    --set mongo-express.env.meConfigMongodbAdminpassword="$MONGO_DB_ADMIN_PASSWORD" \
    --set mongo-express.env.meConfigMongodbUrl="$MONGO_DB_INTERNAL_URL" \
    --wait --timeout=10m --create-namespace --atomic $CAPIF_RESOURCES_RESERVE $CAPIF_STORAGE_ACCESS_MODE $CAPIF_RUN_AS_USER_CONFIG "${extra_args[@]}"
}

install_capif_helm || { echo "helm upgrade/install failed, exiting"; exit 1; }

wait_chart $RELEASE $CAPIF_NAMESPACE
