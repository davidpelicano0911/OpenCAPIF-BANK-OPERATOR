#!/bin/bash
IP=""
NAMESPACE=""

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
  echo "  -i <ip>             IP to use"
  echo "  -n <namespace>      Namespace to get ingress information"
  echo "  -k <kubeconfig>     Kubeconfig to be used"
  echo "  -h                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 prod -i 10.0.0.1 -n mynamespace"
  echo "  $0 -n mynamespace"
  exit 1
}
# Read params
while getopts ":i:n:k:h" opt; do
  case $opt in
    i)
      IP="$OPTARG"
      ;;
    n)
      NAMESPACE="$OPTARG"
      ;;
    k)
      KUBECONFIG="$OPTARG"
      if [ -z "$KUBECONFIG" ]; then
        echo "The variable KUBECONFIG is empty. Using default k8s environment..."
      else
        KUBECONFIG="--kubeconfig $KUBECONFIG"
        echo "The variable KUBECONFIG is not empty. Its value is: $KUBECONFIG"
      fi
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

if [[ -n "$NAMESPACE" && -n "$IP" ]]
then
  echo "IP: $IP and namespace: $NAMESPACE"
elif [[ -n "$NAMESPACE" ]]; then
  if [[ -n "$K8S_IP" ]]; then
    IP=$K8S_IP
    echo "Using K8S_IP found. IP: $IP and namespace: $NAMESPACE"
  fi
else
  echo "IP ($IP) and NAMESPACE ($NAMESPACE) must be set"
  exit -1
fi

echo "# $NAMESPACE Adding IP and hostname to /etc/hosts" >> /etc/hosts

kubectl $KUBECONFIG -n $NAMESPACE get ing|grep -v NAME|awk "{print \"$IP \"\$3}" >> /etc/hosts
