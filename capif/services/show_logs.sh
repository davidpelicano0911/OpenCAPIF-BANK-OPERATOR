#!/bin/bash

# Directories variables setup (no modification needed)
export SERVICES_DIR=$(dirname "$(readlink -f "$0")")

help() {
  echo "Usage: $0 <options>"
  echo "       -c : Show capif services"
  echo "       -v : Show vault service"
  echo "       -r : Show register service"
  echo "       -s : Show Robot Mock Server service"
  echo "       -m : Show monitoring service"
  echo "       -a : Show all services"
  echo "       -f : Follow log output"
  echo "       -h : Show this help"
  exit 1
}

MONITORING_STATE=false
LOG_LEVEL=DEBUG
CAPIF_PRIV_KEY_BASE_64=$(echo "$(cat nginx/certs/server.key)")

if [[ $# -lt 1 ]]
then
  echo "You must specify an option before run script."
  help
fi

FILES=()
echo "${FILES[@]}"
FOLLOW=""

# Needed to avoid write permissions on bind volumes with prometheus and grafana
DUID=$(id -u)
DGID=$(id -g)

# Read params
while getopts "cvrahmfs" opt; do
  case $opt in
    c)
      echo "Show Capif services"
      FILES+=("-f $SERVICES_DIR/docker-compose-capif.yml")
      ;;
    v)
      echo "Show vault service"
      FILES+=("-f $SERVICES_DIR/docker-compose-vault.yml")
      ;;
    r)
      echo "Show register service"
      FILES+=("-f $SERVICES_DIR/docker-compose-register.yml")
      ;;
    s)
      echo "Show Mock Server service"
      FILES+=("-f $SERVICES_DIR/docker-compose-mock-server.yml")
      ;;
    m)
      echo "Show monitoring service"
      FILES+=("-f $SERVICES_DIR/monitoring/docker-compose.yml")
      ;;
    a)
      echo "Show all services"
      FILES=("-f $SERVICES_DIR/docker-compose-capif.yml" -f "$SERVICES_DIR/docker-compose-vault.yml" -f "$SERVICES_DIR/docker-compose-register.yml" -f "$SERVICES_DIR/docker-compose-mock-server.yml" -f "$SERVICES_DIR/monitoring/docker-compose.yml")
      ;;
    f)
      echo "Setup follow logs"
      FOLLOW="-f"
      ;;
    h)
      help
      ;;
    ?)
      echo "Not valid option: -$OPTARG" >&2
      help
      exit 1
      ;;
    :)
      echo "The -$OPTARG option requires an argument." >&2
      help
      exit 1
      ;;
    \*)
      echo "Not valid parameter $opt"
      help
      exit 1
      ;;
  esac
done

if [[ $1 =~ ^- ]]
then
  echo "${FILES[@]}"
else
  help
fi

MONITORING=$MONITORING_STATE LOG_LEVEL=$LOG_LEVEL CAPIF_PRIV_KEY=$CAPIF_PRIV_KEY_BASE_64 DUID=$DUID DGID=$DGID docker compose ${FILES[@]} logs ${FOLLOW}

