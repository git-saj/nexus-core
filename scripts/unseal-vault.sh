#!/bin/bash
set -eo pipefail

# Vault unsealing automation script for nexus-core cluster
# This script automates: init (if needed), Raft join (if needed), unseal (if needed), and status display.

VAULT_NAMESPACE="vault-system"
UNSEAL_KEYS_FILE="${HOME}/.vault-unseal-keys"
ROOT_TOKEN_FILE="${HOME}/.vault-root-token"

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

# Check if kubectl is available and namespace exists
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi

    if ! kubectl get namespace "$VAULT_NAMESPACE" &> /dev/null; then
        error "Vault namespace '$VAULT_NAMESPACE' not found"
    fi
}

# Get Vault pods as array
get_vault_pods() {
    local pods
    pods=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    read -ra pod_array <<< "$pods"
    echo "${pod_array[@]}"
}

# Check if Vault pod is running
is_pod_ready() {
    local pod_name="$1"
    kubectl get pod -n "$VAULT_NAMESPACE" "$pod_name" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"
}

# Check Vault status (sealed/unsealed/initialized)
check_vault_status() {
    local pod_name="$1"
    if ! is_pod_ready "$pod_name"; then
        echo "not_running"
        return
    fi

    local vault_output
    vault_output=$(kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault status 2>&1 || true)

    if echo "$vault_output" | grep -q "Initialized.*false"; then
        echo "uninitialized"
    elif echo "$vault_output" | grep -q "Sealed.*false"; then
        echo "unsealed"
    elif echo "$vault_output" | grep -q "Sealed.*true"; then
        echo "sealed"
    else
        echo "unknown"
    fi
}

# Initialize Vault on the leader pod if needed
initialize_vault() {
    local leader_pod="$1"

    log "Checking if Vault needs initialization on leader pod $leader_pod..."

    local status
    status=$(check_vault_status "$leader_pod")

    if [ "$status" = "uninitialized" ]; then
        if [ -f "$UNSEAL_KEYS_FILE" ]; then
            warn "Unseal keys file exists, but Vault is uninitialized. Overwriting files."
        fi

        log "Initializing Vault..."
        local init_output
        init_output=$(kubectl exec -n "$VAULT_NAMESPACE" "$leader_pod" -- vault operator init -key-shares=5 -key-threshold=3)

        echo "$init_output" | grep "Unseal Key" | awk '{print $4}' > "$UNSEAL_KEYS_FILE"
        echo "$init_output" | grep "Initial Root Token:" | awk '{print $4}' > "$ROOT_TOKEN_FILE"

        chmod 600 "$UNSEAL_KEYS_FILE" "$ROOT_TOKEN_FILE"

        success "Vault initialized. Unseal keys saved to $UNSEAL_KEYS_FILE"
        success "Root token saved to $ROOT_TOKEN_FILE"
        return 0
    else
        log "Vault is already initialized."
        return 1
    fi
}

# Join a follower pod to Raft cluster
join_raft() {
    local pod_name="$1"
    local leader_pod="$2"
    local leader_addr="http://${leader_pod}.vault-internal:8200"  # Adjust if service name differs

    log "Attempting to join $pod_name to Raft cluster using leader $leader_pod..."

    local attempts=3
    local attempt=1
    while [ $attempt -le $attempts ]; do
        if kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault operator raft join "$leader_addr" >/dev/null 2>&1; then
            success "$pod_name joined Raft cluster."
            sleep 3  # Wait for status update
            return 0
        fi
        warn "Join attempt $attempt/$attempts failed for $pod_name."
        sleep $((2 ** attempt))  # Exponential backoff
        ((attempt++))
    done
    warn "Failed to join $pod_name to Raft after $attempts attempts."
    return 1
}

# Unseal a single Vault pod
unseal_vault_pod() {
    local pod_name="$1"

    log "Processing Vault pod: $pod_name"

    if ! is_pod_ready "$pod_name"; then
        warn "Pod $pod_name is not running, skipping."
        return 1
    fi

    local status
    status=$(check_vault_status "$pod_name")

    if [ "$status" = "unsealed" ]; then
        success "Pod $pod_name is already unsealed."
        return 0
    elif [ "$status" != "sealed" ] && [ "$status" != "uninitialized" ] && [ "$status" != "unknown" ]; then
        warn "Unknown status for pod $pod_name, skipping."
        return 1
    fi

    log "Pod $pod_name needs unsealing."

    if [ ! -f "$UNSEAL_KEYS_FILE" ]; then
        error "Unseal keys file not found at $UNSEAL_KEYS_FILE. Run initialization first."
    fi

    local unseal_keys
    mapfile -t unseal_keys < <(head -n 3 "$UNSEAL_KEYS_FILE" 2>/dev/null || echo "")

    if [ ${#unseal_keys[@]} -lt 3 ]; then
        error "Insufficient unseal keys in $UNSEAL_KEYS_FILE (need at least 3)."
    fi

    local success_count=0
    for key in "${unseal_keys[@]}"; do
        if [ -n "$key" ]; then
            log "Applying unseal key $((success_count + 1))/3 to $pod_name..."
            local attempts=3
            local attempt=1
            while [ $attempt -le $attempts ]; do
                if timeout 30 kubectl exec -n "$VAULT_NAMESPACE" "$pod_name" -- vault operator unseal "$key" >/dev/null 2>&1; then
                    ((success_count++))
                    log "Key $success_count/3 applied successfully."
                    break
                fi
                warn "Apply attempt $attempt/$attempts failed (may retry)."
                sleep $((2 ** attempt))
                ((attempt++))
            done
            if [ $attempt -gt $attempts ]; then
                warn "Failed to apply key $((success_count + 1)) after retries."
            fi
            sleep 1
        fi
    done

    sleep 2
    status=$(check_vault_status "$pod_name")
    if [ "$status" = "unsealed" ]; then
        success "Pod $pod_name is now unsealed."
        return 0
    else
        warn "Failed to unseal $pod_name."
        return 1
    fi
}

# Wait for all pods to be ready with exponential backoff
wait_for_pods() {
    local max_attempts=30
    local attempt=1
    local delay=5

    log "Waiting for Vault pods to be running..."

    while [ $attempt -le $max_attempts ]; do
        local vault_pods=($(get_vault_pods))
        if [ ${#vault_pods[@]} -eq 0 ]; then
            log "No Vault pods found, waiting... (attempt $attempt/$max_attempts)"
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff, max 60s
            [ $delay -gt 60 ] && delay=60
            ((attempt++))
            continue
        fi

        local all_running=true
        for pod in "${vault_pods[@]}"; do
            if ! is_pod_ready "$pod"; then
                all_running=false
                break
            fi
        done

        if $all_running; then
            success "All ${#vault_pods[@]} Vault pods are running."
            return 0
        fi

        log "Waiting... (attempt $attempt/$max_attempts)"
        sleep "$delay"
        delay=$((delay * 2))
        [ $delay -gt 60 ] && delay=60
        ((attempt++))
    done

    error "Vault pods failed to become running after $max_attempts attempts."
}

# Show Vault cluster status
show_status() {
    local vault_pods=($(get_vault_pods))
    if [ ${#vault_pods[@]} -eq 0 ]; then
        warn "No Vault pods found."
        return
    fi

    log "Vault cluster status:"
    for pod in "${vault_pods[@]}"; do
        local status
        status=$(check_vault_status "$pod")
        case "$status" in
            "unsealed") echo -e "  ${GREEN}✓${NC} $pod: unsealed" ;;
            "sealed") echo -e "  ${RED}✗${NC} $pod: sealed" ;;
            "uninitialized") echo -e "  ${YELLOW}!${NC} $pod: uninitialized" ;;
            "not_running") echo -e "  ${YELLOW}!${NC} $pod: not running" ;;
            *) echo -e "  ${YELLOW}?${NC} $pod: unknown" ;;
        esac
    done
}

# Main process: init → join → unseal → status
main() {
    log "Starting Vault automation process..."

    check_prerequisites
    wait_for_pods

    local vault_pods=($(get_vault_pods))
    if [ ${#vault_pods[@]} -eq 0 ]; then
        error "No Vault pods found."
    fi

    log "Found ${#vault_pods[@]} Vault pod(s): ${vault_pods[*]}"

    # Assume first pod is leader (sort alphabetically if needed: sort -V)
    local leader_pod="${vault_pods[0]}"

    # Init if needed (only on leader)
    initialize_vault "$leader_pod"

    # Join followers to Raft if needed (skip leader)
    if [ ${#vault_pods[@]} -gt 1 ]; then
        log "Handling Raft joins for followers..."
        for pod in "${vault_pods[@]:1}"; do
            local status=$(check_vault_status "$pod")
            if [ "$status" = "uninitialized" ] || [ "$status" = "unknown" ]; then
                join_raft "$pod" "$leader_pod"
            else
                log "$pod already part of cluster or initialized."
            fi
        done
    fi

    # Unseal all pods if needed
    log "Handling unsealing for all pods..."
    local unsealed_count=0
    for pod in "${vault_pods[@]}"; do
        if unseal_vault_pod "$pod"; then
            ((unsealed_count++))
        fi
    done

    if [ $unsealed_count -gt 0 ]; then
        success "Unsealed $unsealed_count out of ${#vault_pods[@]} pods."
    elif [ $unsealed_count -eq 0 ] && [ ${#vault_pods[@]} -gt 0 ]; then
        success "All pods were already unsealed."
    fi

    show_status

    if [ -f "$ROOT_TOKEN_FILE" ]; then
        log "Root token available at: $ROOT_TOKEN_FILE"
        log "To access Vault, run:"
        log "  export VAULT_TOKEN=\$(cat $ROOT_TOKEN_FILE)"
        log "  kubectl port-forward -n $VAULT_NAMESPACE svc/vault 8200:8200"
        log "  export VAULT_ADDR=http://localhost:8200"
    fi
}

main
