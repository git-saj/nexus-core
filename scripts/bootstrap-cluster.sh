#!/bin/bash
set -euo pipefail

# Bootstrap script for nexus-core RKE2 cluster
# This script automates the complete cluster setup process

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="nexus"
FLUX_NAMESPACE="flux-system"

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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi

    # Check if flux CLI is available
    if ! command -v flux &> /dev/null; then
        error "flux CLI is not installed or not in PATH"
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        error "git is not installed or not in PATH"
    fi

    success "Prerequisites check passed"
}

# Wait for cluster to be ready
wait_for_cluster() {
    log "Waiting for cluster to be ready..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if kubectl cluster-info &> /dev/null; then
            success "Cluster is ready"
            return 0
        fi

        log "Attempt $attempt/$max_attempts - waiting for cluster..."
        sleep 10
        ((attempt++))
    done

    error "Cluster failed to become ready after $max_attempts attempts"
}

# Install Flux
install_flux() {
    log "Installing Flux..."

    # Check if Flux is already installed
    if kubectl get namespace $FLUX_NAMESPACE &> /dev/null; then
        warn "Flux namespace already exists, checking if Flux is running..."
        if kubectl get deployment -n $FLUX_NAMESPACE source-controller &> /dev/null; then
            log "Flux is already installed, skipping installation"
            return 0
        fi
    fi

    # Pre-create namespace
    kubectl create namespace $FLUX_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Apply Flux components
    log "Applying Flux components..."
    kubectl apply -f "$PROJECT_ROOT/flux/clusters/$CLUSTER_NAME/flux-system/gotk-components.yaml"

    # Wait for Flux controllers to be ready
    log "Waiting for Flux controllers to be ready..."
    kubectl wait --for=condition=ready pod -l app=source-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=kustomize-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=helm-controller -n $FLUX_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=notification-controller -n $FLUX_NAMESPACE --timeout=300s

    success "Flux controllers are ready"
}

# Setup Git repository secret
setup_git_secret() {
    log "Setting up Git repository access..."

    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa ]; then
        warn "SSH key not found at ~/.ssh/id_rsa"
        warn "Please ensure you have SSH access to the repository configured"
        warn "You may need to create the flux-system secret manually"
        return 0
    fi

    # Create Git secret for Flux
    kubectl create secret generic flux-system \
        --from-file=identity=~/.ssh/id_rsa \
        --from-file=identity.pub=~/.ssh/id_rsa.pub \
        --from-literal=known_hosts="$(ssh-keyscan github.com)" \
        -n $FLUX_NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    success "Git repository secret configured"
}

# Bootstrap GitRepository and Kustomization
bootstrap_flux_sync() {
    log "Bootstrapping Flux sync..."

    # Apply the GitRepository and Kustomization
    kubectl apply -f "$PROJECT_ROOT/flux/clusters/$CLUSTER_NAME/flux-system/gotk-sync.yaml"

    # Wait for GitRepository to be ready
    log "Waiting for GitRepository to be ready..."
    kubectl wait --for=condition=ready gitrepository/flux-system -n $FLUX_NAMESPACE --timeout=300s

    success "Flux sync bootstrapped"
}

# Wait for platform components
wait_for_platform() {
    log "Waiting for platform components to be deployed..."

    # Wait for platform kustomizations
    local kustomizations=("platform-infrastructure" "platform-configuration" "platform-applications")

    for kust in "${kustomizations[@]}"; do
        log "Waiting for $kust to be ready..."
        kubectl wait --for=condition=ready kustomization/$kust -n $FLUX_NAMESPACE --timeout=600s
    done

    success "Platform components deployed successfully"
}

# Check Vault status and provide unsealing instructions
check_vault_status() {
    log "Checking Vault status..."

    # Wait for Vault pods to be running
    if kubectl get namespace vault-system &> /dev/null; then
        log "Waiting for Vault pods to be running..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault-system --timeout=300s || true

        # Check if Vault is sealed
        vault_pods=$(kubectl get pods -n vault-system -l app.kubernetes.io/name=vault -o jsonpath='{.items[*].metadata.name}')

        if [ -n "$vault_pods" ]; then
            warn "Vault pods are running but may be sealed"
            warn "To unseal Vault, run the following commands for each pod:"
            for pod in $vault_pods; do
                warn "  kubectl exec -n vault-system $pod -- vault operator unseal <unseal-key>"
            done
            warn "After unsealing, you can check status with:"
            warn "  kubectl exec -n vault-system <vault-pod> -- vault status"
        fi
    else
        log "Vault namespace not found yet, it may still be deploying"
    fi
}

# Main execution
main() {
    log "Starting cluster bootstrap process..."

    check_prerequisites
    wait_for_cluster
    install_flux
    setup_git_secret
    bootstrap_flux_sync
    wait_for_platform
    check_vault_status

    success "Bootstrap completed successfully!"
    log "Your GitOps cluster is now running. Check the status with:"
    log "  kubectl get kustomizations -n $FLUX_NAMESPACE"
    log "  kubectl get helmreleases -n $FLUX_NAMESPACE"
    log ""
    log "To monitor the deployment progress:"
    log "  flux get kustomizations --watch"
    log "  flux get helmreleases --watch"
}

# Handle script arguments
case "${1:-}" in
    "check")
        check_prerequisites
        ;;
    "vault-status")
        check_vault_status
        ;;
    *)
        main
        ;;
esac
