#!/bin/bash

# Directories variables setup (no modification needed)
export SERVICES_DIR=$(dirname "$(readlink -f "$0")")
export CAPIF_BASE_DIR=$(dirname "$SERVICES_DIR")
export TEST_FOLDER=$CAPIF_BASE_DIR/tests
export RESULT_FOLDER=$CAPIF_BASE_DIR/results
export ROBOT_DOCKER_FILE_FOLDER=$CAPIF_BASE_DIR/tools/robot

# Image URL and version
export REGISTRY_BASE_URL="labs.etsi.org:5050/ocf/capif/prod"
export OCF_VERSION="v2.x.x-release"

# Capif hostname
export CAPIF_HOSTNAME=capifcore
export CAPIF_HTTP_PORT=8080
export CAPIF_HTTPS_PORT=443

# Register hostname and port
export CAPIF_REGISTER=register
export CAPIF_REGISTER_PORT=8084

# VAULT access configuration
export CAPIF_VAULT=vault
export CAPIF_VAULT_PORT=8200
export CAPIF_VAULT_TOKEN=dev-only-token

# Build and Deployment variables
export MONITORING_STATE=false
export DEPLOY=all
export LOG_LEVEL=DEBUG
export CACHED_INFO=""
export BUILD_DOCKER_IMAGES=true
export REMOVE_IMAGES=false
export ROBOT_MOCK_SERVER=true

# Needed to avoid write permissions on bind volumes with prometheus and grafana
export DUID=$(id -u)
export DGID=$(id -g)

# Mock Server configuration
export MOCK_SERVER_IP=0.0.0.0
export MOCK_SERVER_PORT=9100

# Robot tests variables
export DOCKER_ROBOT_IMAGE=labs.etsi.org:5050/ocf/capif/robot-tests-image
export DOCKER_ROBOT_IMAGE_VERSION=1.0
export DOCKER_ROBOT_TTY_OPTIONS="-ti"

# Mock server variables
export MOCK_SERVER_URL=http://mock-server:${MOCK_SERVER_PORT}
export NOTIFICATION_DESTINATION_URL=http://mock-server:${MOCK_SERVER_PORT}

