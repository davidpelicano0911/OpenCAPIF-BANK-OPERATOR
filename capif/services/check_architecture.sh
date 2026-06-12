#!/bin/bash

echo "Checking all images architecture"

IMAGES=$(docker images|grep -v "REPOSITORY"|awk '{ print $1 ":" $2 }')

for i in $IMAGES; do
  Architecture=$(docker inspect $i|grep Architecture|awk '{ print $2 }')

  echo "Image $i with architecture $Architecture"
done
