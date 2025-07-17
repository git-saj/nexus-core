#!/bin/bash

# Vault Database Secrets Setup Script
# This script configures Vault with the necessary secrets and policies for PostgreSQL and Redis

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VAULT_NAMESPACE="vault-system"
VAULT_SERVICE="vault"
VAULT_PORT="8200"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if vault is ready
check_vault_ready() {
    print_status "Checking if Vault is ready..."

    # Wait for vault pods to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n "$VAULT_NAMESPACE" --timeout=300s

    # Check if vault is initialized and unsealed
    if kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status | grep -q "Sealed.*false"; then
        print_success "Vault is ready and unsealed"
        return 0
    else
        print_error "Vault is not ready or is sealed"
        return 1
    fi
}

# Function to generate random passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to setup vault secrets
setup_vault_secrets() {
    print_status "Setting up Vault secrets for databases..."

    # Generate passwords
    POSTGRES_PASSWORD=$(generate_password)
    REPMGR_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)

    print_status "Generated passwords for PostgreSQL and Redis"

    # Enable KV secrets engine if not already enabled
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || true

    # Store PostgreSQL credentials
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault kv put secret/database/postgresql \
        password="$POSTGRES_PASSWORD" \
        repmgr-password="$REPMGR_PASSWORD"

    # Store Redis credentials
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault kv put secret/database/redis \
        password="$REDIS_PASSWORD"

    print_success "Database secrets stored in Vault"

    # Output passwords for manual reference (optional)
    echo
    print_warning "Generated passwords (store these securely):"
    echo "PostgreSQL admin password: $POSTGRES_PASSWORD"
    echo "PostgreSQL repmgr password: $REPMGR_PASSWORD"
    echo "Redis password: $REDIS_PASSWORD"
}

# Function to setup Kubernetes auth
setup_kubernetes_auth() {
    print_status "Setting up Kubernetes authentication..."

    # Enable Kubernetes auth if not already enabled
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault auth enable kubernetes 2>/dev/null || true

    # Configure Kubernetes auth
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault write auth/kubernetes/config \
        kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

    print_success "Kubernetes authentication configured"
}

# Function to create Vault policies
create_vault_policies() {
    print_status "Creating Vault policies..."

    # Create policy for External Secrets Operator
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault policy write external-secrets - <<EOF
path "secret/data/database/*" {
  capabilities = ["read"]
}

path "secret/metadata/database/*" {
  capabilities = ["list", "read"]
}
EOF

    # Create policy for PostgreSQL
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault policy write postgresql - <<EOF
path "secret/data/database/postgresql" {
  capabilities = ["read"]
}
EOF

    # Create policy for Redis
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault policy write redis - <<EOF
path "secret/data/database/redis" {
  capabilities = ["read"]
}
EOF

    print_success "Vault policies created"
}

# Function to create Kubernetes roles
create_kubernetes_roles() {
    print_status "Creating Kubernetes roles in Vault..."

    # Create role for External Secrets Operator
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault write auth/kubernetes/role/external-secrets \
        bound_service_account_names=external-secrets-vault \
        bound_service_account_namespaces=external-secrets-system \
        policies=external-secrets \
        ttl=24h

    # Create role for PostgreSQL namespace
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault write auth/kubernetes/role/postgresql \
        bound_service_account_names=default \
        bound_service_account_namespaces=postgresql-system \
        policies=postgresql \
        ttl=24h

    # Create role for Redis namespace
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault write auth/kubernetes/role/redis \
        bound_service_account_names=default \
        bound_service_account_namespaces=redis-system \
        policies=redis \
        ttl=24h

    print_success "Kubernetes roles created in Vault"
}

# Function to verify setup
verify_setup() {
    print_status "Verifying Vault setup..."

    # Check if secrets exist
    if kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault kv get secret/database/postgresql >/dev/null 2>&1; then
        print_success "PostgreSQL secrets verified"
    else
        print_error "PostgreSQL secrets not found"
        return 1
    fi

    if kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault kv get secret/database/redis >/dev/null 2>&1; then
        print_success "Redis secrets verified"
    else
        print_error "Redis secrets not found"
        return 1
    fi

    # Check if policies exist
    if kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault policy read external-secrets >/dev/null 2>&1; then
        print_success "External Secrets policy verified"
    else
        print_error "External Secrets policy not found"
        return 1
    fi

    print_success "Vault setup verification completed"
}

# Function to show connection information
show_connection_info() {
    print_status "Database connection information:"
    echo
    echo "PostgreSQL HA:"
    echo "  Host: postgresql-ha-pgpool.postgresql-system.svc.cluster.local"
    echo "  Port: 5432"
    echo "  Database: postgres"
    echo "  Username: postgres"
    echo "  Password: (stored in Vault at secret/database/postgresql)"
    echo
    echo "Redis HA:"
    echo "  Master: redis-ha-master.redis-system.svc.cluster.local:6379"
    echo "  Sentinel: redis-ha-sentinel.redis-system.svc.cluster.local:26379"
    echo "  Password: (stored in Vault at secret/database/redis)"
    echo
    echo "To port-forward for local access:"
    echo "  kubectl port-forward svc/postgresql-ha-pgpool -n postgresql-system 5432:5432"
    echo "  kubectl port-forward svc/redis-ha-master -n redis-system 6379:6379"
}

# Main execution
main() {
    echo "Vault Database Secrets Setup"
    echo "============================"
    echo

    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if Vault is ready
    if ! check_vault_ready; then
        print_error "Vault is not ready. Please ensure Vault is installed, initialized, and unsealed."
        exit 1
    fi

    # Setup Vault
    setup_kubernetes_auth
    create_vault_policies
    create_kubernetes_roles
    setup_vault_secrets

    # Verify setup
    verify_setup

    echo
    print_success "Vault setup completed successfully!"
    echo
    show_connection_info

    echo
    print_warning "Next steps:"
    echo "1. Apply the Flux configurations: 'flux reconcile source git flux-system'"
    echo "2. Monitor the deployments: 'kubectl get pods -n postgresql-system -w'"
    echo "3. Monitor the deployments: 'kubectl get pods -n redis-system -w'"
    echo "4. Check External Secrets: 'kubectl get externalsecrets -A'"
}

# Run main function
main "$@"
