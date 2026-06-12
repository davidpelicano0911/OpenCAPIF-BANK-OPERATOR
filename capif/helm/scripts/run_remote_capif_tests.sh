#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

DOCKER_ROBOT_IMAGE=labs.etsi.org:5050/ocf/capif/robot-tests-image
DOCKER_ROBOT_IMAGE_VERSION=1.0

TEST_FOLDER=$CAPIF_BASE_DIR/tests
RESULT_FOLDER=$CAPIF_BASE_DIR/results
ROBOT_DOCKER_FILE_FOLDER=$CAPIF_BASE_DIR/tools/robot

# nginx Hostname and http port (80 by default) to reach for tests
CAPIF_REGISTER=$REGISTER_HOSTNAME
CAPIF_REGISTER_PORT=443
CAPIF_HTTPS_PORT=443

# VAULT access configuration
CAPIF_VAULT=$VAULT_HOSTNAME
CAPIF_VAULT_PORT=80
CAPIF_VAULT_TOKEN=$VAULT_ACCESS_TOKEN


MOCK_SERVER_URL=http://mock-server-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN:80
NOTIFICATION_DESTINATION_URL=http://mock-server.$CAPIF_NAMESPACE.svc.cluster.local:9100

PLATFORM=$(uname -m)
if [ "x86_64" == "$PLATFORM" ]; then
  DOCKER_ROBOT_IMAGE_VERSION=$DOCKER_ROBOT_IMAGE_VERSION-amd64
else
  DOCKER_ROBOT_IMAGE_VERSION=$DOCKER_ROBOT_IMAGE_VERSION-arm64
fi

echo "CAPIF_HOSTNAME = $CAPIF_HOSTNAME"
echo "CAPIF_REGISTER = $REGISTER_HOSTNAME"
echo "CAPIF_HTTPS_PORT = $CAPIF_HTTPS_PORT"
echo "CAPIF_VAULT = $VAULT_INTERNAL_HOSTNAME"
echo "CAPIF_VAULT_PORT = $VAULT_PORT"
echo "CAPIF_VAULT_TOKEN = $VAULT_ACCESS_TOKEN"
echo "MOCK_SERVER_URL = $MOCK_SERVER_URL"
echo "DOCKER_ROBOT_IMAGE = $DOCKER_ROBOT_IMAGE:$DOCKER_ROBOT_IMAGE_VERSION"
echo "REGISTER_ADMIN_PASSWORD = $REGISTER_ADMIN_PASSWORD"

INPUT_OPTIONS=$@
# Check if input is provided
if [ -z "$1" ]; then
    # Set default value if no input is provided
    INPUT_OPTIONS="--include all"
fi

cd $CAPIF_BASE_DIR

docker >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
    echo "Docker maybe is not installed. Please check if docker CLI is present."
    exit -1
fi

docker pull $DOCKER_ROBOT_IMAGE:$DOCKER_ROBOT_IMAGE_VERSION || echo "Docker image ($DOCKER_ROBOT_IMAGE:$DOCKER_ROBOT_IMAGE_VERSION) not present on repository"
docker images|grep -Eq '^'$DOCKER_ROBOT_IMAGE'[ ]+[ ]'$DOCKER_ROBOT_IMAGE_VERSION''
if [[ $? -ne 0 ]]
then
    read -p "Robot image is not present. To continue, Do you want to build it? (y/n)" build_robot_image
    if [[ $build_robot_image == "y" ]]
    then
        echo "Building Robot docker image."
        cd $ROBOT_DOCKER_FILE_FOLDER
        docker build --no-cache -t $DOCKER_ROBOT_IMAGE:$DOCKER_ROBOT_IMAGE_VERSION .
        cd $CAPIF_BASE_DIR
    else
        exit -2
    fi
fi

mkdir -p $RESULT_FOLDER

docker run -ti --rm --network="host" \
    -v $TEST_FOLDER:/opt/robot-tests/tests \
    -v $RESULT_FOLDER:/opt/robot-tests/results ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}  \
    --variable CAPIF_HOSTNAME:$CAPIF_HOSTNAME \
    --variable CAPIF_HTTPS_PORT:$CAPIF_HTTPS_PORT \
    --variable CAPIF_REGISTER:$CAPIF_REGISTER \
    --variable CAPIF_REGISTER_PORT:$CAPIF_REGISTER_PORT \
    --variable CAPIF_VAULT:$CAPIF_VAULT \
    --variable CAPIF_VAULT_PORT:$CAPIF_VAULT_PORT \
    --variable CAPIF_VAULT_TOKEN:$CAPIF_VAULT_TOKEN \
    --variable NOTIFICATION_DESTINATION_URL:$NOTIFICATION_DESTINATION_URL \
    --variable MOCK_SERVER_URL:$MOCK_SERVER_URL \
    --variable REGISTER_ADMIN_USER:$REGISTER_ADMIN_USER \
    --variable REGISTER_ADMIN_PASSWORD:$REGISTER_ADMIN_PASSWORD $INPUT_OPTIONS
