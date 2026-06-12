#!/bin/bash
source $(dirname "$(readlink -f "$0")")/variables.sh

help() {
  echo "Usage: $1 <options>"
  echo "       -c : Setup different hostname for capif"
  echo "       -R : Setup different hostname for register service"
  echo "       -s : Run Mock server. Default true"
  echo "       -m : Run monitoring service"
  echo "       -l : Set Log Level (default DEBUG). Select one of: [CRITICAL, FATAL, ERROR, WARNING, WARN, INFO, DEBUG, NOTSET]"
  echo "       -r : Remove cached information on build"
  echo "       -v : Set OCF version of images"
  echo "       -f : Services directory. (Default $SERVICES_DIR)"
  echo "       -g : Gitlab base URL. (Default $REGISTRY_BASE_URL)"
  echo "       -b : Build docker images. Default TRUE"
  echo "       -h : show this help"
  exit 1
}

# Get docker compose version
docker_version=$(docker compose version --short | cut -d',' -f1)
IFS='.' read -ra version_components <<< "$docker_version"

if [ "${version_components[0]}" -gt 2 ] || { [ "${version_components[0]}" -eq 2 ] && [ "${version_components[1]}" -ge 10 ]; }; then
  echo "Docker compose version it greater than 2.10"
else
  echo "Docker compose version is not valid. Should be greater than 2.10"
  #exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq is not installed. Please install it first."
    exit 1
fi

# Read params
while getopts ":c:l:ms:hrv:f:g:b:" opt; do
  case $opt in
    c)
      CAPIF_HOSTNAME="$OPTARG"
      ;;
    R)
      CAPIF_REGISTER="$OPTARG"
      ;;
    m)
      MONITORING_STATE=true
      ;;
    s)
      ROBOT_MOCK_SERVER="$OPTARG"
      ;;
    v)
      OCF_VERSION="$OPTARG"
      ;;
    f)
      SERVICES_DIR="$OPTARG"
      ;;
    g)
      REGISTRY_BASE_URL="$OPTARG"
      ;;
    b)
      BUILD_DOCKER_IMAGES="$OPTARG"
      ;;
    h)
      help
      ;;
    l)
      LOG_LEVEL="$OPTARG"
      ;;
    r)
      CACHED_INFO="--no-cache"
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

echo Nginx hostname will be $CAPIF_HOSTNAME, Register Hostname $CAPIF_REGISTER, deploy $DEPLOY, monitoring $MONITORING_STATE

if [ "$BUILD_DOCKER_IMAGES" == "true" ] ; then
    echo '***Building Docker images set as true***'
    BUILD="--build"
else
  echo '***Building Docker images set as false***'
    BUILD="--no-build"
fi

# Deploy Monitoring stack
if [ "$MONITORING_STATE" == "true" ] ; then
    echo '***Monitoring set as true***'
    echo '***Creating Monitoring stack***'
    DUID=$DUID DGID=$DGID docker compose -f "$SERVICES_DIR/monitoring/docker-compose.yml" up --detach $BUILD $CACHED_INFO

    status=$?
    if [ $status -eq 0 ]; then
        echo "*** Monitoring Stack Runing ***"
    else
        echo "*** Monitoring Stack failed to start ***"
        exit $status
    fi
fi

docker network create capif-network

# Deploy Vault service
REGISTRY_BASE_URL=$REGISTRY_BASE_URL OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME docker compose -f "$SERVICES_DIR/docker-compose-vault.yml" up --detach $BUILD $CACHED_INFO

status=$?
if [ $status -eq 0 ]; then
    echo "*** Vault Service Runing ***"
else
    echo "*** Vault failed to start ***"
    exit $status
fi

# Deploy Capif services
REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_HOSTNAME=$CAPIF_HOSTNAME MONITORING=$MONITORING_STATE LOG_LEVEL=$LOG_LEVEL docker compose -f "$SERVICES_DIR/docker-compose-capif.yml" up --detach $BUILD $CACHED_INFO

status=$?
if [ $status -eq 0 ]; then
    echo "*** All Capif services are running ***"
else
    echo "*** Some Capif services failed to start ***"
    exit $status
fi

# Path to the register config.yaml file
REGISTER_CONFIG_FILE="$SERVICES_DIR/register/config.yaml"
# Backup Original config.yaml file
cp $REGISTER_CONFIG_FILE $REGISTER_CONFIG_FILE.bak
# Mark the file as assume-unchanged
git update-index --assume-unchanged "$REGISTER_CONFIG_FILE"

# Edit Register Service URL within ccf in the config.yaml file
yq eval ".ccf.url = \"$CAPIF_HOSTNAME\"" -i "$REGISTER_CONFIG_FILE" -P

# Deploy Register service
CAPIF_PRIV_KEY_BASE_64=$(echo "$(cat ${SERVICES_DIR}/nginx/certs/server.key)")
REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION CAPIF_PRIV_KEY=$CAPIF_PRIV_KEY_BASE_64 LOG_LEVEL=$LOG_LEVEL CAPIF_REGISTER=$CAPIF_REGISTER docker compose -f "$SERVICES_DIR/docker-compose-register.yml" up --detach $BUILD $CACHED_INFO

status=$?
if [ $status -eq 0 ]; then
    echo "*** Register Service are running ***"
else
    echo "*** Register Service failed to start ***"
    exit $status
fi

# Deploy Robot Mock Server
if [ "$ROBOT_MOCK_SERVER" == "true" ] ; then
    echo '***Robot Mock Server set as true***'
    echo '***Creating Robot Mock Server stack***'

    REGISTRY_BASE_URL=$REGISTRY_BASE_URL SERVICES_DIR=$SERVICES_DIR OCF_VERSION=$OCF_VERSION IP=$MOCK_SERVER_IP PORT=$MOCK_SERVER_PORT docker compose -f "$SERVICES_DIR/docker-compose-mock-server.yml" up --detach $BUILD $CACHED_INFO
    status=$?
    if [ $status -eq 0 ]; then
        echo "*** Mock Server Runing ***"
    else
        echo "*** Mock Server failed to start ***"
        exit $status
    fi
fi

exit $status
