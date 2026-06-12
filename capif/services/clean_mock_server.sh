#!/bin/bash
source $(dirname "$(readlink -f "$0")")/variables.sh

# Directories variables setup (no modification needed)
FILE="$SERVICES_DIR/docker-compose-mock-server.yml"

echo "Executing 'docker compose down' for file $FILE"
docker compose -f "$FILE" down --rmi all
status=$?
  if [ $status -eq 0 ]; then
      echo "*** Removed Service from $FILE ***"
  else
      echo "*** Some services of $FILE failed on clean ***"
  fi

docker volume prune --all --force

echo "Clean complete."
