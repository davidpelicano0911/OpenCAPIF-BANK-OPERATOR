#!/bin/bash
source $(dirname "$(readlink -f "$0")")/variables.sh

help() {
  echo "Usage: $1 <options>"
  echo "       -i : Setup different host ip for mock server (default 0.0.0.0)"
  echo "       -p : Setup different port for mock server (default 9100)"
  echo "       -h : show this help"
  exit 1
}

MOCK_SERVER_IP=0.0.0.0
MOCK_SERVER_PORT=9100

# Read params
while getopts ":i:p:h" opt; do
  case $opt in
    i)
      MOCK_SERVER_IP="$OPTARG"
      ;;
    p)
      MOCK_SERVER_PORT=$OPTARG
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

echo Robot Framework Mock Server will listen on $MOCK_SERVER_IP:$MOCK_SERVER_PORT

docker network create capif-network || echo "capif-network previously created on docker networks"

MOCK_SERVER_IP=$IP MOCK_SERVER_PORT=$PORT docker compose -f "$SERVICES_DIR/docker-compose-mock-server.yml" up --detach --build

status=$?
if [ $status -eq 0 ]; then
    echo "*** All Capif services are running ***"
else
    echo "*** Some Capif services failed to start ***"
    exit $status
fi
