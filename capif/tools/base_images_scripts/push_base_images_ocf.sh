#!/bin/bash
source $(dirname "$(readlink -f "$0")")/common.sh

PLATFORMS=("linux/arm64"
"linux/amd64")

BASIC_IMAGES=("python:3-slim-bullseye"
"nginx:1.27.1"
"vault:1.13.2"
"ubuntu:20.04"
"redis:7.4.2-alpine"
"mongo-express:1.0.0-alpha.4"
"mongo:6.0.2"
"busybox:1.37.0")

docker login labs.etsi.org:5050
for basic_image in "${BASIC_IMAGES[@]}"; do
  echo "$basic_image processing"
  MANIFEST_AMEND=""
  for platform in "${PLATFORMS[@]}";do
    docker pull $basic_image --platform $platform
    echo "$basic_image pulled for platform $platform"
    tag=$(echo $platform | awk -F'/' '{print $NF}')
    docker tag $basic_image labs.etsi.org:5050/ocf/capif/$basic_image-$tag
    echo "labs.etsi.org:5050/ocf/capif/$basic_image-$tag tagged"
    docker push labs.etsi.org:5050/ocf/capif/$basic_image-$tag
    echo "labs.etsi.org:5050/ocf/capif/$basic_image-$tag pushed"
    MANIFEST_AMEND="$MANIFEST_AMEND --amend labs.etsi.org:5050/ocf/capif/$basic_image-$tag"
  done

  docker manifest create labs.etsi.org:5050/ocf/capif/$basic_image $MANIFEST_AMEND
  echo "labs.etsi.org:5050/ocf/capif/$basic_image Manifest created with amend $MANIFEST_AMEND"
  docker manifest push labs.etsi.org:5050/ocf/capif/$basic_image
  echo "labs.etsi.org:5050/ocf/capif/$basic_image Manifest pushed"
done
