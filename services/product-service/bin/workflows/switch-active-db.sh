#!/bin/bash
set -eo pipefail

# Source functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/functions.sh"

# Configuration
NAMESPACE="default"
CONFIGMAP_NAME="pim-db-active"
KEY="ACTIVE_DB"
DB_A="product-service-a"
DB_B="product-service-b"

# Get the current kubectl context instead of hard-coding it
CLUSTER_NAME=$(kubectl config current-context)
printf "[INFO] Using kubectl context: %s\n" "${CLUSTER_NAME}"

# Verify kubectl connectivity before proceeding
verify_kubectl_connection "${CLUSTER_NAME}"

# Check current database configuration
ACTIVE_DB=$(get_active_db)
NEXT_DB=$(get_passive_db)

printf "[INFO] Switching ACTIVE_DB from %s to %s...\n" "${ACTIVE_DB}" "${NEXT_DB}"

# Apply and verify the change (without explicit context since we're using the current one)
printf "[INFO] Updating configmap and verifying it was applied correctly\n"
if kubectl -n "${NAMESPACE}" create configmap "${CONFIGMAP_NAME}" --from-literal="${KEY}=${NEXT_DB}" --dry-run=client -o yaml | kubectl apply -f -; then
  FINAL_DB=$(kubectl -n "${NAMESPACE}" get configmap "${CONFIGMAP_NAME}" -o jsonpath="{.data.${KEY}}" 2>/dev/null)
  if [ "${FINAL_DB}" = "${NEXT_DB}" ]; then
    printf "[SUCCESS] ACTIVE_DB successfully set to: %s\n" "${FINAL_DB}"
  else
    printf "[ERROR] Failed to verify database change. Current value: %s\n" "${FINAL_DB}"
    exit 1
  fi
else
  printf "[ERROR] Failed to update configmap\n"
  exit 1
fi
