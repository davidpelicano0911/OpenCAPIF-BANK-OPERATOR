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

helm_exists() {
    local name="$1"
    local ns="$2"

    echo "Check if Helm release '$name' exists in namespace '$ns'..."

    helm $KUBECONFIG status "$name" -n "$ns" >/dev/null 2>&1
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
        echo "All data associated with CAPIF service will be permanently lost."
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

# helm $KUBECONFIG uninstall $CAPIF_NAME_VERSION_CHART -n $CAPIF_NAMESPACE || echo "$CAPIF_NAME_VERSION_CHART is not present"




if helm_exists "$CAPIF_NAME_VERSION_CHART" "$CAPIF_NAMESPACE"; then
    helm uninstall "$CAPIF_NAME_VERSION_CHART" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $CAPIF_NAME_VERSION_CHART, it may not exist or there may be an issue with Helm."
else
    echo "Release $CAPIF_NAME_VERSION_CHART not found, searching in other namespaces..."
    if helm_exists "$RELEASE_NAME_REGISTER" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_REGISTER" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_REGISTER, it may not exist or there may be an issue with Helm."
    fi
    if helm_exists "$RELEASE_NAME_SVC" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_SVC" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_SVC, it may not exist or there may be an issue with Helm."
    fi
    if helm_exists "$RELEASE_NAME_COMMONS" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_COMMONS" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_COMMONS, it may not exist or there may be an issue with Helm."
    fi
    if helm_exists "$RELEASE_NAME_DB_EXPRESS" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_DB_EXPRESS" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_DB_EXPRESS, it may not exist or there may be an issue with Helm."
    fi
    if helm_exists "$RELEASE_NAME_DB" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_DB" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_DB, it may not exist or there may be an issue with Helm."
    fi
    if helm_exists "$RELEASE_NAME_MONITORING" "$CAPIF_NAMESPACE"; then
      helm uninstall "$RELEASE_NAME_MONITORING" -n "$CAPIF_NAMESPACE" || echo "Failed to uninstall $RELEASE_NAME_MONITORING, it may not exist or there may be an issue with Helm."
    # else
    #   echo "Release $CAPIF_NAME_VERSION_CHART and its associated components not found in namespace $CAPIF_NAMESPACE."
    fi
fi

kubectl $KUBECONFIG delete namespace $CAPIF_NAMESPACE || echo "$CAPIF_NAMESPACE is not present"

echo "Uninstallation complete. The CAPIF service and all associated data have been removed."