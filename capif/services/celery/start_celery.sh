#!/bin/bash

if [ "$CELERY_MODE" = "worker" ]; then
    echo "Starting Celery Worker..."
    celery -A tasks worker
elif [ "$CELERY_MODE" = "beat" ]; then
    echo "Iniciando Celery Beat..."
    celery -A tasks beat
else
    echo "ERROR: The environment variable CELERY_MODE is not set correctly (worker|beat)"
    exit 1
fi