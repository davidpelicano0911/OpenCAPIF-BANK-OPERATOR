#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

# Populate variables
TOTAL_INVOKERS=10
TOTAL_PROVIDERS=10

help() {
  echo "Usage: $0 [environment] [options]"
  echo ""
  echo "  environment         Optional. Environment name to use (e.g. dev, prod)."
  echo "                      If not specified, 'dev' will be used by default."
  echo ""
  echo "Options:"
  echo "  -p <total>          Total providers to create (default: 10)"
  echo "  -i <total>          Total invokers to create (default: 10)"
  echo "  -h                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 prod -p 20 -i 15"
  echo "  $0 -p 5"
  exit 1
}

# Read params
while getopts ":p:i:h" opt; do
  case $opt in
    p)
      TOTAL_PROVIDERS=$OPTARG
      ;;
    i)
      TOTAL_INVOKERS=$OPTARG
      ;;
    h)
      help
      ;;  
    \?)
      echo "Not valid option: -$OPTARG" >&2
      help
      ;;
    :)
      echo "The -$OPTARG option requires an argument." >&2
      help
      ;;
  esac
done

# Other Stuff
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

# Mock Server
MOCK_SERVER_URL=http://mock-server-$CAPIF_CI_ENV_ENDPOINT.$CAPIF_DOMAIN:80
NOTIFICATION_DESTINATION_URL=http://mock-server.$CAPIF_NAMESPACE.svc.cluster.local:9100

PLATFORM=$(uname -m)
if [ "x86_64" == "$PLATFORM" ]; then
  DOCKER_ROBOT_IMAGE_VERSION=$DOCKER_ROBOT_IMAGE_VERSION-amd64
else
  DOCKER_ROBOT_IMAGE_VERSION=$DOCKER_ROBOT_IMAGE_VERSION-arm64
fi

# Show variables
echo "CAPIF_HOSTNAME = $CAPIF_HOSTNAME"
echo "CAPIF_REGISTER = $CAPIF_REGISTER"
echo "CAPIF_HTTP_PORT = $CAPIF_HTTP_PORT"
echo "CAPIF_HTTPS_PORT = $CAPIF_HTTPS_PORT"
echo "CAPIF_VAULT = $CAPIF_VAULT"
echo "CAPIF_VAULT_PORT = $CAPIF_VAULT_PORT"
echo "CAPIF_VAULT_TOKEN = $CAPIF_VAULT_TOKEN"
echo "TOTAL_USERS=$TOTAL_USERS"
echo "USERNAME_PREFIX=$USERNAME_PREFIX"
echo "USER_PASSWORD=$USER_PASSWORD"
echo "MOCK_SERVER_URL=$MOCK_SERVER_URL"
echo "NOTIFICATION_DESTINATION_URL=$NOTIFICATION_DESTINATION_URL"
echo "DOCKER_ROBOT_IMAGE = $DOCKER_ROBOT_IMAGE:$DOCKER_ROBOT_IMAGE_VERSION"

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

cd $CAPIF_BASE_DIR

mkdir -p $RESULT_FOLDER

docker run -ti --rm --network="host" \
  -v $TEST_FOLDER:/opt/robot-tests/tests \
  -v $RESULT_FOLDER:/opt/robot-tests/results ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}  \
  --variable CAPIF_HOSTNAME:$CAPIF_HOSTNAME \
  --variable CAPIF_HTTP_PORT:$CAPIF_HTTP_PORT \
  --variable CAPIF_HTTPS_PORT:$CAPIF_HTTPS_PORT \
  --variable CAPIF_REGISTER:$CAPIF_REGISTER \
  --variable CAPIF_REGISTER_PORT:$CAPIF_REGISTER_PORT \
  --variable CAPIF_VAULT:$CAPIF_VAULT \
  --variable CAPIF_VAULT_PORT:$CAPIF_VAULT_PORT \
  --variable CAPIF_VAULT_TOKEN:$CAPIF_VAULT_TOKEN \
  --variable NOTIFICATION_DESTINATION_URL:$NOTIFICATION_DESTINATION_URL \
  --variable MOCK_SERVER_URL:$MOCK_SERVER_URL \
  --variable TOTAL_PROVIDERS:$TOTAL_PROVIDERS \
  --variable TOTAL_INVOKERS:$TOTAL_INVOKERS \
  --variable REGISTER_ADMIN_USER:$REGISTER_ADMIN_USER \
  --variable REGISTER_ADMIN_PASSWORD:$REGISTER_ADMIN_PASSWORD \
  --include populate-create
