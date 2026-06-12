#!/bin/bash

gunicorn -k uvicorn.workers.UvicornH11Worker --bind 0.0.0.0:8080 \
         --chdir /usr/src/app/service_apis wsgi:app


