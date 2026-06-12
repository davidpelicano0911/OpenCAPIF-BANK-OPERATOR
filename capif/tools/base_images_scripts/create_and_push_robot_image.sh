#!/bin/bash
source $(dirname "$(readlink -f "$0")")/common.sh

DOCKER_ROBOT_IMAGE=labs.etsi.org:5050/ocf/capif/robot-tests-image
DOCKER_ROBOT_IMAGE_VERSION=1.0

TEST_FOLDER=$CAPIF_BASE_DIR/tests
RESULT_FOLDER=$CAPIF_BASE_DIR/results
ROBOT_DOCKER_FILE_FOLDER=$TOOLS_DIR/robot

cd $ROBOT_DOCKER_FILE_FOLDER
docker login labs.etsi.org:5050

docker build --no-cache --platform linux/amd64 -t ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-amd64 .
docker push ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-amd64

docker build --no-cache --platform linux/arm64 -t ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-arm64 .
docker push ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-arm64

docker manifest create ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION} \
  --amend ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-amd64 \
  --amend ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}-arm64
docker manifest push ${DOCKER_ROBOT_IMAGE}:${DOCKER_ROBOT_IMAGE_VERSION}
