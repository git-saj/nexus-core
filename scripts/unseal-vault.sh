#!/bin/bash
set -eo pipefail

# Vault unsealing automation script for nexus-core cluster
# This script automates the unsealing process for Vault pods

VAULT_NAMESPACE="vault-system"
UNSEAL_KEYS_FILE="${HOME}/.vault-unseal-keys"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if kubectl is available
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi

    if ! kubectl get namespace "$VAULT_NAMESPACE" &> /dev/null; then
        error "Vault namespace '$VAULT_NAMESPACE' not found"
    fi
}

# Get Vault pods
get_vault_pods() {
    kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo ""
}

# Check if Vault pod is ready
is_pod_ready() {
    local pod_name="$1"
    kubectl get pod -n "$VAULT_NAMESPACE" "$pod_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"
}

# Check Vault status
check_vault_status() {
    local pod_name="$1"
    if ! is_pod_ready "$pod_name"; then
        echo "not_ready"
        return
    fi

    # Check vault status using simple text parsing
    local vault_output
    vault_output=$(kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault status 2>&1 || true)

    if echo "$vault_output" | grep -q "Sealed.*false"; then
        echo "unsealed"
    elif echo "$vault_output" | grep -q "Sealed.*true"; then
        echo "sealed"
    else
        echo "unknown"
    fi
}

# Initialize Vault if needed
initialize_vault() {
    local pod_name="$1"

    log "Checking if Vault needs initialization on pod $pod_name..."

    # Check if vault is initialized by trying to read status
    local vault_output
    vault_output=$(kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault status 2>&1 || true)

    if echo "$vault_output" | grep -q "Vault is not initialized"; then
        log "Vault is not initialized. Initializing..."

        local init_output
        init_output=$(kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault operator init -key-shares=5 -key-threshold=3)

        # Extract unseal keys and root token from text output
        echo "$init_output" | grep "Unseal Key" | awk '{print $4}' > "$UNSEAL_KEYS_FILE"
        echo "$init_output" | grep "Initial Root Token:" | awk '{print $4}' > "${HOME}/.vault-root-token"

        chmod 600 "$UNSEAL_KEYS_FILE" "${HOME}/.vault-root-token"

        success "Vault initialized. Unseal keys saved to $UNSEAL_KEYS_FILE"
        success "Root token saved to ${HOME}/.vault-root-token"

        return 0
    else
        log "Vault is already initialized"
        return 1
    fi
}

# Unseal a single Vault pod
unseal_vault_pod() {
    local pod_name="$1"

    log "Checking status of Vault pod: $pod_name"

    if ! is_pod_ready "$pod_name"; then
        warn "Pod $pod_name is not ready, skipping"
        return 1
    fi

    local vault_status
    vault_status=$(check_vault_status "$pod_name")

    case "$vault_status" in
        "unsealed")
            success "Pod $pod_name is already unsealed"
            log "Continuing to next pod..."
            return 0
            ;;
        "sealed")
            log "Pod $pod_name is sealed, attempting to unseal..."
            ;;
        "not_ready")
            warn "Pod $pod_name is not ready, skipping"
            return 1
            ;;
        *)
            warn "Unknown status for pod $pod_name, attempting to unseal anyway..."
            ;;
    esac

    # Check if unseal keys file exists
    if [ ! -f "$UNSEAL_KEYS_FILE" ]; then
        # Try to initialize if no keys exist
        if initialize_vault "$pod_name"; then
            log "Proceeding with unseal after initialization..."
        else
            error "Unseal keys file not found at $UNSEAL_KEYS_FILE and Vault is already initialized. Please provide unseal keys manually."
        fi
    fi

    # Read unseal keys (first 3 keys are needed for threshold of 3)
    local unseal_keys
    mapfile -t unseal_keys < <(head -n 3 "$UNSEAL_KEYS_FILE" 2>/dev/null || echo "")

    if [ ${#unseal_keys[@]} -lt 3 ]; then
        error "Insufficient unseal keys found in $UNSEAL_KEYS_FILE. Need at least 3 keys."
    fi

    # Unseal the pod
    local success_count=0
    for key in "${unseal_keys[@]}"; do
        if [ -n "$key" ]; then
            log "Applying unseal key $((success_count + 1))/3 to pod $pod_name..."
            set +e  # Don't exit on kubectl failure
            kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault operator unseal "$key" > /dev/null 2>&1
            local unseal_result=$?
            set -e

            if [ $unseal_result -eq 0 ]; then
                ((success_count++))
                log "Unseal key ${success_count}/3 applied successfully"
            else
                warn "Failed to apply unseal key $((success_count + 1))"
            fi
        fi
    done

    # Check final status
    sleep 2
    vault_status=$(check_vault_status "$pod_name")
    if [ "$vault_status" = "unsealed" ]; then
        success "Pod $pod_name is now unsealed"
        return 0
    else
        warn "Failed to unseal pod $pod_name after applying keys"
        return 1
    fi
}

# Join raft peers (for HA setup)
join_raft_peers() {
    local vault_pods=("$@")
    local leader_pod="${vault_pods[0]}"

    log "Setting up Raft cluster with leader: $leader_pod"

    # Skip the first pod (leader)
    for pod in "${vault_pods[@]:1}"; do
        if is_pod_ready "$pod"; then
            log "Joining $pod to Raft cluster..."
            kubectl exec -n "$VAULT_NAMESPACE" "$pod" -- vault operator raft join "http://${leader_pod}.vault-internal:8200" || warn "Failed to join $pod to cluster (may already be joined)"
        fi
    done
}

# Wait for all pods to be ready
wait_for_pods() {
    local max_attempts=30
    local attempt=1

    log "Waiting for Vault pods to be ready..."

    while [ $attempt -le $max_attempts ]; do
        local vault_pods
        vault_pods=$(get_vault_pods)

        if [ -z "$vault_pods" ]; then
            log "No Vault pods found, waiting... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
            continue
        fi

        local all_ready=true
        for pod in $vault_pods; do
            if ! is_pod_ready "$pod"; then
                all_ready=false
                break
            fi
        done

        if $all_ready; then
            success "All Vault pods are ready"
            return 0
        fi

        log "Waiting for pods to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done

    error "Vault pods failed to become ready after $max_attempts attempts"
}

# Show Vault cluster status
show_status() {
    local vault_pods
    vault_pods=$(get_vault_pods)

    if [ -z "$vault_pods" ]; then
        warn "No Vault pods found"
        return
    fi

    log "Vault cluster status:"
    for pod in $vault_pods; do
        local status
        status=$(check_vault_status "$pod")
        case "$status" in
            "unsealed")
                echo -e "  ${GREEN}✓${NC} $pod: unsealed"
                ;;
            "sealed")
                echo -e "  ${RED}✗${NC} $pod: sealed"
                ;;
            "not_ready")
                echo -e "  ${YELLOW}!${NC} $pod: not ready"
                ;;
            *)
                echo -e "  ${YELLOW}?${NC} $pod: unknown status"
                ;;
        esac
    done
}

# Main unsealing process
unseal_vault() {
    log "Starting Vault unsealing process..."

    check_prerequisites
    wait_for_pods

    local vault_pods
    vault_pods=$(get_vault_pods)

    if [ -z "$vault_pods" ]; then
        error "No Vault pods found"
    fi

    # Convert space-separated string to array
    local vault_pods_array
    read -ra vault_pods_array <<< "$vault_pods"

    log "Found ${#vault_pods_array[@]} Vault pod(s): ${vault_pods_array[*]}"
    log "Starting pod processing loop..."

    # Unseal each pod
    local unsealed_count=0
    local pod_index=1
    for pod in "${vault_pods_array[@]}"; do
        log "Processing pod $pod_index/${#vault_pods_array[@]}: $pod"

        # Process pod with explicit error handling
        local result=0
        set +e
        unseal_vault_pod "$pod"
        result=$?
        set -e

        if [ $result -eq 0 ]; then
            unsealed_count=$((unsealed_count + 1))
            log "Successfully processed pod $pod ($unsealed_count unsealed so far)"
        else
            warn "Failed to process pod $pod (exit code: $result), but continuing with other pods"
        fi
        pod_index=$((pod_index + 1))
        log "Finished processing pod $pod"
        echo "---"
    done

    log "Completed processing all pods. Total processed: $unsealed_count out of ${#vault_pods_array[@]}"

    if [ $unsealed_count -gt 0 ]; then
        log "Setting up Raft cluster relationships..."
        join_raft_peers "${vault_pods_array[@]}"

        success "Unsealed $unsealed_count out of ${#vault_pods_array[@]} Vault pods"
        show_status

        if [ -f "${HOME}/.vault-root-token" ]; then
            log "Root token available at: ${HOME}/.vault-root-token"
            log "To access Vault, run:"
            log "  export VAULT_TOKEN=\$(cat ${HOME}/.vault-root-token)"
            log "  kubectl port-forward -n vault-system svc/vault 8200:8200"
            log "  export VAULT_ADDR=http://localhost:8200"
        fi
    else
        warn "Failed to unseal any Vault pods"
    fi
}

# Script usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  unseal    Unseal all Vault pods (default)"
    echo "  status    Show current Vault cluster status"
    echo "  init      Initialize Vault (first time setup)"
    echo "  help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  VAULT_NAMESPACE      Vault namespace (default: vault-system)"
    echo "  UNSEAL_KEYS_FILE     Path to unseal keys file (default: ~/.vault-unseal-keys)"
}

# Main execution
case "${1:-unseal}" in
    "unseal")
        unseal_vault
        ;;
    "status")
        check_prerequisites
        show_status
        ;;
    "init")
        check_prerequisites
        vault_pods=$(get_vault_pods)
        if [ -n "$vault_pods" ]; then
            first_pod=$(echo "$vault_pods" | cut -d' ' -f1)
            initialize_vault "$first_pod"
        else
            error "No Vault pods found"
        fi
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        error "Unknown command: $1. Use 'help' for usage information."
        ;;
esac
