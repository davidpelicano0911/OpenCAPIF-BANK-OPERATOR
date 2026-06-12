#!/bin/bash

# Use custom kubeconfig. If you set here the path to a kubeconfig file it will be used in installation/uninstallation scripts
CUSTOM_KUBECONFIG=""

if [ -n "$CUSTOM_KUBECONFIG" ]; then
    # Case 1: CUSTOM_KUBECONFIG already defined (path or flag)
    if [[ "$CUSTOM_KUBECONFIG" == *"--kubeconfig"* ]]; then
        echo "CUSTOM_KUBECONFIG already contains --kubeconfig"
    else
        CUSTOM_KUBECONFIG="--kubeconfig $CUSTOM_KUBECONFIG"
    fi
else
    # Case 2: CUSTOM_KUBECONFIG empty → check KUBECONFIG
    if [ -n "$KUBECONFIG" ]; then
        if [[ "$KUBECONFIG" == *"--kubeconfig"* ]]; then
            CUSTOM_KUBECONFIG="$KUBECONFIG"
            echo "Using KUBECONFIG with --kubeconfig already set"
        else
            CUSTOM_KUBECONFIG="--kubeconfig $KUBECONFIG"
            echo "Using KUBECONFIG path: $CUSTOM_KUBECONFIG"
        fi
    else
        echo "No CUSTOM_KUBECONFIG or KUBECONFIG defined. Using default context."
        CUSTOM_KUBECONFIG=""
    fi
fi

export CUSTOM_KUBECONFIG

# timestap to use along scripts
export timestamp=$(date +"%Y%m%d_%H%M%S")

# k8s public ip. NONE will indicate no local register service DNS resolution to reach CCF, empty value will try to get ip of ingress-nginx-controller NodePort
# and any other vaule will set resolution to K8S_IP set for CAPIF_HOSTNAME.
export K8S_IP=""

# Directories variables setup (no modification needed)
export SCRIPTS_DIR=$(dirname "$(readlink -f "$0")")
export HELM_DIR=$(dirname "$SCRIPTS_DIR")
export CAPIF_BASE_DIR=$(dirname "$HELM_DIR")

# Docker registry to be used in deployment
export BASE_DOCKER_REGISTRY="labs.etsi.org:5050/ocf/capif"
# Common Configurations
## Log level to be used in deployment [CRITICAL, FATAL, ERROR, WARNING, WARN, INFO, DEBUG, NOTSET]
export LOG_LEVEL=DEBUG
## Register admin user and password to be used on testing
export REGISTER_ADMIN_USER='admin'
export REGISTER_ADMIN_PASSWORD='password123'

# Print scripts directory
echo "The /helm/scripts directory is: $SCRIPTS_DIR"
echo "The /helm directory is: $HELM_DIR"
echo "The base directory is: $CAPIF_BASE_DIR"

# Configuration needed before use installation/uninstallation scripts

# Vault installation variables
## Vault configuration
export VAULT_HOSTNAME=vault.testbed.develop
export VAULT_NAMESPACE=ocf-vault
export VAULT_SERVICE_NAME='vault'
export LABEL_TO_CHECK="app.kubernetes.io/name"
## File to store key and token
export VAULT_FILE="$HELM_DIR/vault_keys.txt"
## Vault domains to be included
export DOMAIN1=*.testbed.pre-production
export DOMAIN2=*.testbed.validation
export DOMAIN3=*.testbed.develop
## Vault Storage Configuration
export VAULT_STORAGE_CLASS=nfs-01
export VAULT_STORAGE_SIZE=10Gi
## Vault configuration job
VAULT_JOB_NAME=vault-pki

# Monitoring installation variables
## Prometheus Hostname to be used at ingress configuration
export PROMETHEUS_HOSTNAME=prometheus.testbed.develop
export SKOONER_HOSTNAME=skooner.testbed.develop
export GRAFANA_HOSTNAME=grafana.testbed.develop
## Monitoring namespace and service name
export MONITORING_NAMESPACE=monitoring
export MONITORING_SERVICE_NAME=monitoring
## Monitoring Services enabled
export MONITORING_SNOOKER_ENABLED=false
export MONITORING_GRAFANA_ENABLED=false
export MONITORING_PROMETHEUS_ENABLED=true

# OpenCAPIF deployment variables
export CAPIF_RESOURCES_RESERVE="YES"
export CAPIF_RESOURCES_LIMITS_CPU=200m
export CAPIF_RESOURCES_LIMITS_MEMORY=256Mi
export CAPIF_RESOURCES_REQUESTS_CPU=1m
export CAPIF_RESOURCES_REQUESTS_MEMORY=1Mi
## Storage Class
export CAPIF_STORAGE_CLASS=nfs-01
export CAPIF_STORAGE_ACCESS_MODE="ReadWriteMany"
export CAPIF_GRAFANA_STORAGE_SIZE=10Gi
export CAPIF_LOKI_STORAGE_SIZE=100Mi
export CAPIF_MONGO_STORAGE_SIZE=8Gi
export CAPIF_MONGO_REGISTER_STORAGE_SIZE=8Gi
export CAPIF_TEMPO_STORAGE_SIZE=3Gi
## Register and Capif hostname to be deployed
export CAPIF_HOSTNAME="capif.testbed.develop"
export REGISTER_HOSTNAME="register.testbed.develop"
## namespace to use
export CAPIF_NAMESPACE=ocf-capif
## version to be used on deployment
export CAPIF_NAME_VERSION_CHART=ocf-release4
## Configuration of endpoints in ingress for grafana, mock-server and both mongo express instances.
### this configuration is used to add this script to ocf-mon-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN mock-server-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN mongo-express-register-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN mongo-express-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN
export CAPIF_CI_ENV_ENDPOINT=capif
### Domain to ve used in grafana, mock-server and both mongo express instances.
export CAPIF_DOMAIN=testbed.develop
## Configuration of images to be used on deplyment
### Docker Registry to download images (must be accesible by k8s cluster)
export CAPIF_DOCKER_REGISTRY="$BASE_DOCKER_REGISTRY/prod"
### Tag to be used
export CAPIF_IMAGE_TAG="v1.0.0-release"
## Prometheus url, usually internal k8s hostname (if capif will be deployed on same k8s cluster) with port 9090
export PROMETHEUS_URL="http://$MONITORING_SERVICE_NAME-prometheus.$MONITORING_NAMESPACE.svc.cluster.local:9090"
## vault capif configuration
export VAULT_INTERNAL_HOSTNAME="$VAULT_SERVICE_NAME.$VAULT_NAMESPACE.svc.cluster.local"
export VAULT_PORT="8200"
export VAULT_ACCESS_TOKEN="dev-only-token"
## Only for testing purpouses, configuration of mock-server port
export MOCK_SERVER_PORT="9100"

# CAPIF Monitoring deployment variables
export CAPIF_GRAFANA_ENABLED=true
export CAPIF_LOKI_ENABLED=true
export CAPIF_FLUENTBIT_ENABLED=true
export CAPIF_TEMPO_ENABLED=true
export CAPIF_OTELCOLLECTOR_ENABLED=true

# special configuration for capif deployment

## Mongo DBs
export MONGO_DB_ADMIN_USER="root"
export MONGO_DB_ADMIN_PASSWORD="example"
export MONGO_DB_REGISTER_ADMIN_USER="root"
export MONGO_DB_REGISTER_ADMIN_PASSWORD="example"

## Setup KUBECONFIG
export KUBECONFIG=$CUSTOM_KUBECONFIG

## If CAPIF_STORAGE_CLASS is longhorn, then we need to set runAsUser to 0 in some deployments to allow write on PVC
export CAPIF_RUN_AS_USER_CONFIG=""

## SED command, in MacOS sed is different and need gnu-sed (gsed)
export SED_CMD=sed

# Load environment variables from file
## Directory for environment variables
ENV_DIR="$SCRIPTS_DIR/envs"

## Environment selection (default: dev)
ENVIRONMENT="${1:-dev}"
ENV_FILE="$ENV_DIR/$ENVIRONMENT.env"

if [ -f "$ENV_FILE" ]; then
    echo "Loading environment configuration: $ENVIRONMENT"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Environment file not found: $ENV_FILE. Using default values."
fi

######### POST PROCESSING VARIABLES SET ########
### To deploy in other environment we need to setup urls according to it and also using specific kubeconfig:
if [ -f "$VAULT_FILE" ] && [ -s "$VAULT_FILE" ]; then
    VAULT_ACCESS_TOKEN=$(awk '/Initial Root Token/{ print $4 }' $VAULT_FILE)
    echo "$VAULT_FILE exists and has content."
else
    echo "$VAULT_FILE not exists or content is empty."
fi
echo "Using value on VAULT_ACCESS_TOKEN=$VAULT_ACCESS_TOKEN"



### If K8S_IP is empty, then script will try to get ingress-nginx-controller NodePort to grant DNS resolution for register to connect locally to CAPIF nginx
if [ "$K8S_IP" == "NONE" ]; then
    echo "K8S_IP value is NONE. Register service will not have local DNS resolution"
elif [ -z "$K8S_IP" ]; then
    K8S_IP=$(kubectl $KUBECONFIG get svc -A | grep ingress-nginx-controller | awk '/NodePort/{ print $4 }')
    echo "K8S_IP value will be $K8S_IP"
fi

capif_services=("fluentbit"
"grafana"
"loki"
"mock-server"
"mongo"
"mongo-express"
"mongo-register"
"mongo-register-express"
"nginx"
"ocf-access-control-policy"
"ocf-api-invocation-logs"
"ocf-api-invoker-management"
"ocf-api-provider-management"
"ocf-auditing-api-logs"
"ocf-discover-service-api"
"ocf-events"
"ocf-helper"
"ocf-publish-service-api"
"ocf-register"
"ocf-routing-info"
"ocf-security"
"otelcollector"
"redis"
"renderer")

if [ -n "$CAPIF_STORAGE_ACCESS_MODE" ]; then
    CAPIF_STORAGE_ACCESS_MODE="--set mongo.persistence.accessModes[0]=$CAPIF_STORAGE_ACCESS_MODE
    --set mongo-register.persistence.accessModes[0]=$CAPIF_STORAGE_ACCESS_MODE
    --set loki.persistence.accessModes[0]=$CAPIF_STORAGE_ACCESS_MODE
    --set grafana.persistence.accessModes[0]=$CAPIF_STORAGE_ACCESS_MODE 
    "
fi


if [ "$CAPIF_STORAGE_CLASS" == "longhorn" ]; then
    echo "$CAPIF_STORAGE_CLASS needs to configure runAsUser at mongo, mongo-register and grafana to 0, in order to allow write con PVC created."
    CAPIF_RUN_AS_USER_CONFIG="--set mongo.securityContext.runAsUser=0
    --set mongo-register.securityContext.runAsUser=0
    --set grafana.securityContext.runAsUser=0"
fi


if [[ "$OSTYPE" == "darwin"* ]]; then
  # Require gnu-sed.
  if ! [ -x "$(command -v gsed)" ]; then
    echo "Error: 'gsed' is not istalled." >&2
    echo "If you are using Homebrew, install with 'brew install gnu-sed'." >&2
    exit 1
  fi
  SED_CMD=gsed
fi

if [ "$CAPIF_RESOURCES_RESERVE" == "NO" ]; then
    echo "No Limits will be requested on deployment"
    CAPIF_RESOURCES_RESERVE=""
    ${SED_CMD} -i "s/^resources:.*/resources: {}/g" $HELM_DIR/**/**/**/values.yaml
    ${SED_CMD} -i "s/^  limits:/#  limits:/g" $HELM_DIR/**/**/**/values.yaml
    ${SED_CMD} -i "s/^    cpu:/#    cpu:/g" $HELM_DIR/**/**/**/values.yaml
    ${SED_CMD} -i "s/^    memory:/#    memory:/g" $HELM_DIR/**/**/**/values.yaml
    ${SED_CMD} -i "s/^  requests:/#  requests:/g" $HELM_DIR/**/**/**/values.yaml
else
    CAPIF_RESOURCES_RESERVE=""
    for service in "${capif_services[@]}"; do
        CAPIF_RESOURCES_RESERVE="$CAPIF_RESOURCES_RESERVE --set $service.resources.limits.cpu=$CAPIF_RESOURCES_LIMITS_CPU
        --set $service.resources.limits.memory=$CAPIF_RESOURCES_LIMITS_MEMORY
        --set $service.resources.requests.cpu=$CAPIF_RESOURCES_REQUESTS_CPU
        --set $service.resources.requests.memory=$CAPIF_RESOURCES_REQUESTS_MEMORY "
    done
fi

export RELEASE_NAME_MONITORING=${CAPIF_NAME_VERSION_CHART}-monitoring
export RELEASE_NAME_DB=${CAPIF_NAME_VERSION_CHART}-db
export RELEASE_NAME_DB_EXPRESS=${CAPIF_NAME_VERSION_CHART}-db-express
export RELEASE_NAME_COMMONS=${CAPIF_NAME_VERSION_CHART}-commons
export RELEASE_NAME_SVC=${CAPIF_NAME_VERSION_CHART}-svc
export RELEASE_NAME_REGISTER=${CAPIF_NAME_VERSION_CHART}-register

wait_chart() {
    echo "WAIT CHART: $1 in namespace $2"
    local RELEASE=$1
    local NAMESPACE=$2

    for deploy in $(kubectl get deploy -n "$NAMESPACE" -l app.kubernetes.io/instance=$RELEASE -o jsonpath='{.items[*].metadata.name}'); do
        echo "   → Waiting rollout of $deploy ..."
        kubectl rollout status deployment/"$deploy" -n "$NAMESPACE" --timeout=300s
    done
}

# DB URLs
# export MONGO_DB_REGISTER_INTERNAL_URL="mongodb://$MONGO_DB_REGISTER_ADMIN_USER:$MONGO_DB_REGISTER_ADMIN_PASSWORD@mongo-register.$CAPIF_NAMESPACE.svc.cluster.local:27017/"
# export MONGO_DB_INTERNAL_URL="mongodb://$MONGO_DB_ADMIN_USER:$MONGO_DB_ADMIN_PASSWORD@mongo.$CAPIF_NAMESPACE.svc.cluster.local:27017/"
export MONGO_DB_REGISTER_INTERNAL_URL="mongodb://$MONGO_DB_REGISTER_ADMIN_USER:$MONGO_DB_REGISTER_ADMIN_PASSWORD@mongo-register:27017/"
export MONGO_DB_INTERNAL_URL="mongodb://$MONGO_DB_ADMIN_USER:$MONGO_DB_ADMIN_PASSWORD@mongo:27017/"
