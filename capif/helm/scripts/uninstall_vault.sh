#!/bin/bash

# Capture the first parameter as a possible environment
ENVIRONMENT="dev"
if [[ "$1" != -* && -n "$1" ]]; then
  ENVIRONMENT="$1"
  shift
fi

# Load variables for the selected environment
source "$(dirname "$0")/variables.sh" "$ENVIRONMENT"

help() {
  echo "Usage: $0 [environment] [options]"
  echo ""
  echo "  environment         Optional. Environment name to use (e.g. dev, prod)."
  echo "                      If not specified, 'dev' will be used by default."
  echo ""
  echo "Options:"
  echo "  -y                  Force uninstall component"
  echo "  -h                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 prod -y"
  echo "  $0"
  exit 1
}

export FORCE=0
# Read params
while getopts ":yh" opt; do
  case $opt in
    y)
      FORCE=1
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

if [ "$FORCE" == "0" ]; then
    # Function to display a warning message
    warning_message() {
        echo "WARNING: This uninstallation process is irreversible."
        echo "All data associated with Vault service will be permanently lost."
        echo "Are you sure you want to continue? (yes/no)"
    }

    # Display the warning message
    warning_message

    # Read the user input
    read -r USER_INPUT

    # Check if the user confirmed the uninstallation
    if [ "$USER_INPUT" != "yes" ]; then
        echo "Uninstallation aborted by the user."
        exit 1
    fi
else
    echo "Forced uninstall"
fi

# Proceed with the uninstallation process
echo "Proceeding with uninstallation..."

helm $KUBECONFIG uninstall $VAULT_SERVICE_NAME -n $VAULT_NAMESPACE
kubectl $KUBECONFIG delete job $VAULT_JOB_NAME  -n $VAULT_NAMESPACE || echo "No vault $VAULT_JOB_NAME job present"
kubectl $KUBECONFIG delete namespace $VAULT_NAMESPACE

echo "Uninstallation complete. The Vault service and all associated data have been removed."