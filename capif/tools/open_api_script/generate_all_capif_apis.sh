#!/bin/bash

# This script generates all CAPIF APIs defined in the 3GPP TS 29222 series.
# This script must setup APIS_FOLDER variable to point to the folder where
# all the OpenAPI files are stored. (them must be placed under openapi-generator). Copy them to that folder
# before running this script.
# OPEN_API_GENERATOR_FOLDER variable must point to the openapi-generator folder

# Steps to run this script:
# 1. Install Docker
# 2. Clone openapi-generator from https://github.com/OpenAPITools/openapi-generator
# 3. Copy all OpenAPI files to a folder inside the openapi-generator folder.
# 4. Run this script with the desired options.

# Mostrar ayuda
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -a <apis_folder>           Folder containing OpenAPI files (default: APIs)"
  echo "  -c <composite_project>     Name of the output project folder (default: CAPIF-generated-new)"
  echo "  -g <generator_folder>      Path to openapi-generator folder (default: /path/to/openapi-generator)"
  echo "  -h                        Show this help message"
  echo ""
  echo "Steps to run this script:"
  echo "  1. Install Docker"
  echo "  2. Clone openapi-generator from https://github.com/OpenAPITools/openapi-generator"
  echo "  3. Copy all CAPIF API files to a folder inside the openapi-generator folder."
  echo "  4. Run this script with the desired options."
  echo ""
  echo "Example:"
  echo "  $0 -a APIs -c MyProject -g /path/to/openapi-generator"
  exit 0
}

# Parámetros por defecto
APIS_FOLDER=APIs
COMPOSITE_PROJECT=CAPIF-latest
OPEN_API_GENERATOR_FOLDER=/path/to/openapi-generator

# Leer parámetros
while getopts ":a:c:g:h" opt; do
  case $opt in
    a)
      APIS_FOLDER="$OPTARG"
      ;;
    c)
      COMPOSITE_PROJECT="$OPTARG"
      ;;
    g)
      OPEN_API_GENERATOR_FOLDER="$OPTARG"
      ;;
    h)
      show_help
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      ;;
  esac
done

# Local variables
ENDPOINTS=()
SERVICE_NAMES=()
OUTPUT_HOST_BASE_DIRECTORY=out/$COMPOSITE_PROJECT
DOCKER_COMPOSE_FILENAME=$OUTPUT_HOST_BASE_DIRECTORY/docker-compose-test.yml
NGINX_CONF_FILE=$OUTPUT_HOST_BASE_DIRECTORY/nginx.conf

# Change to openapi-generator directory (limitation at run-in-docker.sh script)
cd $OPEN_API_GENERATOR_FOLDER

# Validar directorios
if [ ! -d "$APIS_FOLDER" ]; then
  echo "APIs folder '$APIS_FOLDER' does not exist."
  exit 1
fi
if [ ! -d "$OPEN_API_GENERATOR_FOLDER" ]; then
  echo "OpenAPI generator folder '$OPEN_API_GENERATOR_FOLDER' does not exist."
  exit 1
fi

echo "docker compose file: $DOCKER_COMPOSE_FILENAME"
# Create output folder
mkdir -p $OUTPUT_HOST_BASE_DIRECTORY

# rm $DOCKER_COMPOSE_FILENAME || true
cat > $DOCKER_COMPOSE_FILENAME << EOF
services:
EOF

function createPythonServer {
    SWAGGER_FILE=$1
    API_NAME=$(basename -s .yaml $SWAGGER_FILE)
    ENDPOINT=$(awk '/- url: /{ print $3 }' $SWAGGER_FILE|awk -F / '{ print $2}')
    OUTPUT=$OUTPUT_HOST_BASE_DIRECTORY/$API_NAME/
    echo "SWAGGER_FILE: $SWAGGER_FILE"
    echo "API_NAME: $API_NAME"
    echo "ENDPOINT: $ENDPOINT"
    echo "OUTPUT DIRECTORY: $OUTPUT"
    ENDPOINTS+=($ENDPOINT)
    SERVICE_NAME=$(echo $ENDPOINT | sed 's/-/_/g')
    $OPEN_API_GENERATOR_FOLDER/run-in-docker.sh generate -i $SWAGGER_FILE \
       -g python-flask \
       -o /gen/$OUTPUT \
       --package-name=$SERVICE_NAME
    cat >> $DOCKER_COMPOSE_FILENAME << EOF
  $ENDPOINT:
    build: $API_NAME/.
    expose:
      - "8080"
EOF
}

echo "Generating services for APIs in $APIS_FOLDER"
CAPIF_FILES=$(ls $APIS_FOLDER|awk -v dir="$APIS_FOLDER" '/TS29222/{ print dir "/"$0 }')
echo "CAPIF_FILES: $CAPIF_FILES"
for CAPIF_FILE in ${CAPIF_FILES[*]}
do
createPythonServer $CAPIF_FILE
done

cat >> $DOCKER_COMPOSE_FILENAME << EOF
  nginx:
    image: nginx:latest
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "8080:8080"
    depends_on:
EOF

for endpoint in ${ENDPOINTS[*]}
do
cat >> $DOCKER_COMPOSE_FILENAME << EOF
      - $endpoint
EOF
done

cat > $NGINX_CONF_FILE << EOF
user  nginx;

events {
    worker_connections   1000;
}
http {
        server {
              listen 8080;
EOF


for endpoint in ${ENDPOINTS[*]}
do
cat >> $NGINX_CONF_FILE << EOF
              location /$endpoint {
                proxy_pass http://$endpoint:8080;
              }
EOF
done

cat >> $NGINX_CONF_FILE << EOF
        }
}
EOF

echo "Check all generated services under $OPEN_API_GENERATOR_FOLDER/$OUTPUT_HOST_BASE_DIRECTORY folder"