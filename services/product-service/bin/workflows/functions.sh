#!/bin/bash

# Verify kubectl connectivity to cluster
# Usage: verify_kubectl_connection "cluster-name"
verify_kubectl_connection() {
  local CLUSTER_NAME="${1:-$(kubectl config current-context 2>/dev/null || echo 'unknown')}"
  
  printf "[INFO] Verifying kubectl connectivity to cluster: %s\n" "${CLUSTER_NAME}" >&2
  
  # Test basic connectivity by trying to get cluster info
  if ! kubectl cluster-info &>/dev/null; then
    printf "[ERROR] Failed to connect to Kubernetes cluster: %s\n" "${CLUSTER_NAME}" >&2
    printf "[ERROR] Please ensure:\n" >&2
    printf "[ERROR] 1. kubectl is installed and configured\n" >&2
    printf "[ERROR] 2. The cluster context '%s' exists\n" "${CLUSTER_NAME}" >&2
    printf "[ERROR] 3. You have proper authentication to the cluster\n" >&2
    printf "[ERROR] Run 'kubectl config get-contexts' to see available contexts\n" >&2
    printf "[ERROR] Current context: %s\n" "$(kubectl config current-context 2>/dev/null || echo 'none')" >&2
    exit 1
  fi
  
  printf "[INFO] Successfully connected to cluster: %s\n" "${CLUSTER_NAME}" >&2
}

# Returns the passive database as stdout
# Usage: PASSIVE_DB=$(get_passive_db)
get_passive_db() {
  local ACTIVE_DB=$(get_active_db)
  local NEXT_DB=""
  if [ "${ACTIVE_DB}" = "product-service-a" ]; then
    NEXT_DB="product-service-b"
  else
    NEXT_DB="product-service-a"
  fi
  echo "${NEXT_DB}"
}

# Returns the current active database as stdout
# Usage: ACTIVE_DB=$(get_active_db)
get_active_db() {
  local NAMESPACE="default"
  local CONFIGMAP_NAME="pim-db-active"
  local KEY="ACTIVE_DB"
  local ACTIVE_DB=""
  local DEFAULT_DB="product-service-a"

  printf "[INFO] Checking current database configuration...\n" >&2

  # Check if configmap exists, get current ACTIVE_DB value
  if kubectl -n "${NAMESPACE}" get configmap "${CONFIGMAP_NAME}" &>/dev/null; then
    ACTIVE_DB=$(kubectl -n "${NAMESPACE}" get configmap "${CONFIGMAP_NAME}" -o jsonpath="{.data.${KEY}}" 2>/dev/null || true)
    if [ -z "${ACTIVE_DB}" ]; then
      printf "[WARN] Configmap exists but %s not set\n" "${KEY}" >&2
      ACTIVE_DB="${DEFAULT_DB}"
    else  
      printf "[INFO] Current ACTIVE_DB: %s\n" "${ACTIVE_DB}" >&2
    fi
  else
    printf "[WARN] Configmap %s does not exist\n" "${CONFIGMAP_NAME}" >&2
    ACTIVE_DB="${DEFAULT_DB}"
  fi
  
  echo "${ACTIVE_DB}"
}

# Verify that required environment variables are set
# Usage: `verify_required_env_vars "MONGODB_PASSWORD_PRODUCTION" "MONGODB_PASSWORD_STAGE"`
verify_required_env_vars() {
  local REQUIRED_VARS=("$@")
  if [ ${#REQUIRED_VARS[@]} -eq 0 ]; then
    printf "[WARN] No environment variables specified to verify\n" >&2
    return 1
  fi
  
  for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then 
      printf "[WARN] Environment variable %s is not set\n" "${var}" >&2
      exit 1
    fi
  done
}


