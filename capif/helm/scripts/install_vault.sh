#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

# Function to get the service status
get_service_status() {
    kubectl $KUBECONFIG get pods -n "$VAULT_NAMESPACE" -l $LABEL_TO_CHECK="$VAULT_SERVICE_NAME" -o jsonpath='{.items[*].status.phase}'
}

# Function to get the number of ready replicas
get_ready_replicas() {
    kubectl $KUBECONFIG get pods -n "$VAULT_NAMESPACE" -l $LABEL_TO_CHECK="$VAULT_SERVICE_NAME" -o jsonpath='{.items[*].status.containerStatuses[0].ready}'
}

# Function to get the number of ready replicas
get_started_replicas() {
    kubectl $KUBECONFIG get pods -n "$VAULT_NAMESPACE" -l $LABEL_TO_CHECK="$VAULT_SERVICE_NAME" -o jsonpath='{.items[*].status.containerStatuses[0].started}'
}

get_succeeded_job_status() {
    kubectl $KUBECONFIG get jobs -n "$VAULT_NAMESPACE" -o jsonpath='{.items[*].status.succeeded}'
}

get_failed_job_status() {
    kubectl $KUBECONFIG get jobs -n "$VAULT_NAMESPACE" -o jsonpath='{.items[*].status.failed}'
}

get_completion_job_status() {
    kubectl $KUBECONFIG get jobs -n "$VAULT_NAMESPACE" -o jsonpath='{.items[*].status.conditions[0].status}'
}

get_completed_type_job_status(){
    kubectl $KUBECONFIG get jobs -n "$VAULT_NAMESPACE" -o jsonpath='{.items[*].status.conditions[0].type}'
}

helm $KUBECONFIG repo add hashicorp https://helm.releases.hashicorp.com

helm $KUBECONFIG upgrade --install vault hashicorp/vault -n $VAULT_NAMESPACE --set server.ingress.enabled=true \
--set server.ingress.hosts[0].host="$VAULT_HOSTNAME" \
--set server.ingress.ingressClassName=nginx \
--set server.dataStorage.storageClass=$VAULT_STORAGE_CLASS \
--set server.dataStorage.size=$VAULT_STORAGE_SIZE \
--set server.standalone.enabled=true --create-namespace

# Loop to wait until the service is in "Running" state and has 0/1 ready replicas
while true; do
    SERVICE_STATUS=$(get_service_status)
    READY_REPLICAS=$(get_ready_replicas)
    STARTED_REPLICAS=$(get_started_replicas)

    echo "Service status: $SERVICE_STATUS"
    echo "Ready replicas: $READY_REPLICAS"
    echo "Started Replicas: $STARTED_REPLICAS"
    
    if [ "$SERVICE_STATUS" == "Running" ] && [ "$READY_REPLICAS" == "false" ] && [ "$STARTED_REPLICAS" == "true" ]; then
        echo "The service $VAULT_SERVICE_NAME is in RUNNING state and has 0/1 ready replicas."
        break
    else
        echo "Waiting for the service $VAULT_SERVICE_NAME to be in RUNNING state and have 0/1 ready replicas..."
        sleep 5
    fi
done

echo "The service $VAULT_SERVICE_NAME is now in the desired state."

# Init vault
echo ""
echo "Init vault"
kubectl $KUBECONFIG exec -ti vault-0 -n $VAULT_NAMESPACE -- vault operator init -key-shares=1 -key-threshold=1 > $VAULT_FILE

# Remove control characters
cat $VAULT_FILE | ${SED_CMD} -r 's/\x1B\[[0-9;]*[JKmsu]//g' | ${SED_CMD} -e 's/[^[:print:]\t\n]//g' > $VAULT_FILE.tmp
mv $VAULT_FILE.tmp $VAULT_FILE

# get UNSEAL Key and TOKEN
UNSEAL_KEY=$(awk '/Unseal Key 1/{ print $4 }' $VAULT_FILE)
VAULT_TOKEN=$(awk '/Initial Root Token/{ print $4 }' $VAULT_FILE)

echo "UNSEAL KEY: $UNSEAL_KEY"
echo "VAULT TOKEN: $VAULT_TOKEN"

kubectl $KUBECONFIG exec -ti vault-0 -n $VAULT_NAMESPACE -- vault operator unseal $UNSEAL_KEY

# Loop to wait until the service is in "Running" state and has 1/1 ready replicas
while true; do
    SERVICE_STATUS=$(get_service_status)
    READY_REPLICAS=$(get_ready_replicas)
    STARTED_REPLICAS=$(get_started_replicas)

    echo "Service status: $SERVICE_STATUS"
    echo "Ready replicas: $READY_REPLICAS"
    echo "Started Replicas: $STARTED_REPLICAS"
    
    if [ "$SERVICE_STATUS" == "Running" ] && [ "$READY_REPLICAS" == "true" ] && [ "$STARTED_REPLICAS" == "true" ]; then
        echo "The service $VAULT_SERVICE_NAME is in RUNNING state and has 0/1 ready replicas."
        break
    else
        echo "Waiting for the service $VAULT_SERVICE_NAME to be in RUNNING state and have 1/1 ready replicas..."
        sleep 5
    fi
done

${SED_CMD} -i "s/namespace:.*/namespace: $VAULT_NAMESPACE/g" $HELM_DIR/vault-job/vault-job.yaml
${SED_CMD} -i "s/VAULT_TOKEN=.*/VAULT_TOKEN=$VAULT_TOKEN/g" $HELM_DIR/vault-job/vault-job.yaml
${SED_CMD} -i "s/DOMAIN1=.*/DOMAIN1=$DOMAIN1/g" $HELM_DIR/vault-job/vault-job.yaml
${SED_CMD} -i "s/DOMAIN2=.*/DOMAIN2=$DOMAIN2/g" $HELM_DIR/vault-job/vault-job.yaml
${SED_CMD} -i "s/DOMAIN3=.*/DOMAIN3=$DOMAIN3/g" $HELM_DIR/vault-job/vault-job.yaml

kubectl $KUBECONFIG delete job $VAULT_JOB_NAME -n $VAULT_NAMESPACE || echo "No vault job present"
kubectl $KUBECONFIG -n $VAULT_NAMESPACE apply -f $HELM_DIR/vault-job/

# Check job status
while true; do
    SUCCEEDED_JOB_STATUS=$(get_succeeded_job_status)
    FAILED_JOB_STATUS=$(get_failed_job_status)
    COMPLETION_JOB_STATUS=$(get_completion_job_status)
    COMPLETED_TYPE_JOB_STATUS=$(get_completed_type_job_status)

    echo "SUCCEEDED_JOB_STATUS: $SUCCEEDED_JOB_STATUS"
    echo "FAILED_JOB_STATUS: $FAILED_JOB_STATUS"
    echo "COMPLETION_JOB_STATUS: $COMPLETION_JOB_STATUS"
    echo "COMPLETED_TYPE_JOB_STATUS: $COMPLETED_TYPE_JOB_STATUS"

    if [ "$FAILED_JOB_STATUS" != "" ]; then
        echo "The vault job fails, check variables."
        exit -1
    elif [ "$SUCCEEDED_JOB_STATUS" != "" ] && (( SUCCEEDED_JOB_STATUS > 0 )) && { [ "$COMPLETED_TYPE_JOB_STATUS" == "Complete" ] || [ "$COMPLETED_TYPE_JOB_STATUS" == "SuccessCriteriaMet" ]; } && [ "$COMPLETION_JOB_STATUS" == "True" ]; then
        echo "The vault job succeeded."
        break
    else
        echo "Waiting for the service $VAULT_SERVICE_NAME to be in RUNNING state and have 0/1 ready replicas..."
        sleep 5
    fi
done

echo "Job Success"
# Loop to wait until the service is in "Running" state and has 0/1 ready replicas

while true; do
    SERVICE_STATUS=$(get_service_status)
    READY_REPLICAS=$(get_ready_replicas)
    STARTED_REPLICAS=$(get_started_replicas)

    echo "Service status: $SERVICE_STATUS"
    echo "Ready replicas: $READY_REPLICAS"
    echo "Started Replicas: $STARTED_REPLICAS"
    
    if [ "$SERVICE_STATUS" == "Running" ] && [ "$READY_REPLICAS" == "true" ] && [ "$STARTED_REPLICAS" == "true" ]; then
        echo "The service $VAULT_SERVICE_NAME is in RUNNING state and has 1/1 ready replicas."
        break
    else
        echo "Waiting for the service $VAULT_SERVICE_NAME to be in RUNNING state and have 1/1 ready replicas..."
        sleep 5
    fi
done

echo "The service $VAULT_SERVICE_NAME is successfully deployed."
