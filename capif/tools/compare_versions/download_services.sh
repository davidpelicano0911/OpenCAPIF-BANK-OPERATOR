#!/usr/bin/env bash
set -euo pipefail

# List of CAPIF services
SERVICES=(
  "TS29222_CAPIF_API_Invoker_Management_API.yaml"
  "TS29222_CAPIF_API_Provider_Management_API.yaml"
  "TS29222_CAPIF_Access_Control_Policy_API.yaml"
  "TS29222_CAPIF_Auditing_API.yaml"
  "TS29222_CAPIF_Discover_Service_API.yaml"
  "TS29222_CAPIF_Events_API.yaml"
  "TS29222_CAPIF_Logging_API_Invocation_API.yaml"
  "TS29222_CAPIF_Publish_Service_API.yaml"
  "TS29222_CAPIF_Routing_Info_API.yaml"
  "TS29222_CAPIF_Security_API.yaml"
)

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --route <5g_repo_path> --output <output_path> [--service <yaml_file>]

Options:
  --route     Path to the 5G repo containing the YAML files.
  --output    Folder where the generated code will be stored.
  --service   (Optional) One of the following YAML files:
              ${SERVICES[*]}
  -h, --help  Show this help message.

Examples:
  $(basename "$0") --route /path/5g --output /tmp/capif
  $(basename "$0") --route /path/5g --output /tmp/capif --service TS29222_CAPIF_Events_API.yaml
EOF
}

# Argument parsing (style: --key value)
ROUTE=""
OUTPUT=""
SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --route)  ROUTE="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --service) SERVICE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# Basic validations
[[ -z "$ROUTE"  ]] && echo "Error: --route is required."  >&2 && usage && exit 1
[[ -z "$OUTPUT" ]] && echo "Error: --output is required." >&2 && usage && exit 1

if ! command -v openapi-generator >/dev/null 2>&1; then
  echo "Error: 'openapi-generator' is not installed or not in PATH." >&2
  exit 1
fi

if [[ ! -d "$ROUTE" ]]; then
  echo "Error: the provided route '$ROUTE' does not exist." >&2
  exit 1
fi

mkdir -p "$OUTPUT"

# If a service is specified, validate it
if [[ -n "$SERVICE" ]]; then
  valid=false
  for s in "${SERVICES[@]}"; do
    if [[ "$s" == "$SERVICE" ]]; then
      valid=true
      break
    fi
  done
  if [[ "$valid" != true ]]; then
    echo "Error: the service '$SERVICE' is not valid." >&2
    echo "It must be one of: ${SERVICES[*]}" >&2
    exit 1
  fi

  path="$ROUTE/$SERVICE"
  if [[ ! -f "$path" ]]; then
    echo "Error: the service '$SERVICE' does not exist in the route '$ROUTE'." >&2
    exit 1
  fi

  base="${SERVICE%.*}"
  echo "Downloading and building service: $SERVICE"
  openapi-generator generate -i "$path" -g python-flask -o "$OUTPUT/$base"
else
  # Process all services
  for svc in "${SERVICES[@]}"; do
    path="$ROUTE/$svc"
    echo "Downloading and building service: $svc"
    openapi-generator generate -i "$path" -g python-flask -o "$OUTPUT/${svc%.*}"
  done
fi

echo "All services have been downloaded and built."
