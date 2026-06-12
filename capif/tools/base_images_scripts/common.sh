#!/bin/bash

# Directories variables setup (no modification needed)
export IMAGE_SCRIPTS_DIR=$(dirname "$(readlink -f "$0")")
export TOOLS_DIR=$(dirname "$IMAGE_SCRIPTS_DIR")
export CAPIF_BASE_DIR=$(dirname "$TOOLS_DIR")