#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <yaml_path> <service_name>"
  echo "Example: $0 openapi/auth.yaml auth"
  exit 1
fi

YAML_PATH="$1"
SERVICE_NAME="$2"
SERVICE_DIR="services/$SERVICE_NAME"

# Clean previous service folder if it exists
rm -rf "$SERVICE_DIR"

# Generate the service using OpenAPI Generator
openapi-generator generate \
  -i "$YAML_PATH" \
  -g python-flask \
  -o "$SERVICE_DIR" \
  --additional-properties=packageName="$SERVICE_NAME"

# Move generated inner folder to the root of the service directory
if [ -d "$SERVICE_DIR/$SERVICE_NAME" ]; then
  mv "$SERVICE_DIR/$SERVICE_NAME"/* "$SERVICE_DIR"/
  rm -rf "$SERVICE_DIR/$SERVICE_NAME"
fi

# Files to delete
FILES_TO_DELETE=(
  ".dockerignore"
  ".gitignore"
  ".openapi-generator-ignore"
  ".travis.yml"
  "Dockerfile"
  "git_push.sh"
  "README.md"
  "requirements.txt"
  "setup.py"
  "test-requirements.txt"
  "tox.ini"
)

# Directories to delete
DIRS_TO_DELETE=(
  ".openapi-generator"
  ".github"
  "test"
  "docs"
)

# Remove unnecessary files and folders
for file in "${FILES_TO_DELETE[@]}"; do
  rm -f "$SERVICE_DIR/$file"
done

for dir in "${DIRS_TO_DELETE[@]}"; do
  rm -rf "$SERVICE_DIR/$dir"
done

echo "✅ Service '$SERVICE_NAME' successfully generated from '$YAML_PATH'"
