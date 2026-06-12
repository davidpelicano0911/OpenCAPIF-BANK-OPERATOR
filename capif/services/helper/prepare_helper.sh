#!/bin/bash


gunicorn -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8080 \
         --chdir /usr/src/app/helper_service wsgi:asgi_app