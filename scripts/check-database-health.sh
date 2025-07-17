#!/bin/bash

# Database Health Check Script
# This script monitors the health of PostgreSQL and Redis clusters

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_NAMESPACE="postgresql-system"
REDIS_NAMESPACE="redis-system"
VAULT_NAMESPACE="vault-system"
ESO_NAMESPACE="external-secrets-system"

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

print_header() {
    echo
    echo "=================================="
    echo "$1"
    echo "=================================="
}

# Function to check namespace exists
check_namespace() {
    local namespace=$1
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check External Secrets Operator
check_external_secrets() {
    print_header "External Secrets Operator Status"

    if ! check_namespace "$ESO_NAMESPACE"; then
        print_error "External Secrets namespace '$ESO_NAMESPACE' not found"
        return 1
    fi

    # Check ESO pods
    print_status "Checking External Secrets Operator pods..."
    kubectl get pods -n "$ESO_NAMESPACE" -o wide

    # Check if pods are ready
    local ready_pods=$(kubectl get pods -n "$ESO_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
    local total_pods=$(kubectl get pods -n "$ESO_NAMESPACE" --no-headers | wc -l)

    if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        print_success "All ESO pods are running ($ready_pods/$total_pods)"
    else
        print_warning "ESO pods status: $ready_pods/$total_pods running"
    fi

    # Check SecretStores
    print_status "Checking SecretStores..."
    kubectl get secretstore,clustersecretstore -A

    # Check ExternalSecrets
    print_status "Checking ExternalSecrets..."
    kubectl get externalsecrets -A

    echo
}

# Function to check PostgreSQL
check_postgresql() {
    print_header "PostgreSQL HA Status"

    if ! check_namespace "$POSTGRES_NAMESPACE"; then
        print_error "PostgreSQL namespace '$POSTGRES_NAMESPACE' not found"
        return 1
    fi

    # Check PostgreSQL pods
    print_status "Checking PostgreSQL pods..."
    kubectl get pods -n "$POSTGRES_NAMESPACE" -o wide

    # Check services
    print_status "Checking PostgreSQL services..."
    kubectl get svc -n "$POSTGRES_NAMESPACE"

    # Check PVCs
    print_status "Checking PostgreSQL storage..."
    kubectl get pvc -n "$POSTGRES_NAMESPACE"

    # Check if primary/replica are running
    local postgres_pods=$(kubectl get pods -n "$POSTGRES_NAMESPACE" -l app.kubernetes.io/component=postgresql --no-headers | grep -c "Running" || echo "0")
    local pgpool_pods=$(kubectl get pods -n "$POSTGRES_NAMESPACE" -l app.kubernetes.io/component=pgpool --no-headers | grep -c "Running" || echo "0")

    print_status "PostgreSQL pods running: $postgres_pods"
    print_status "PgPool pods running: $pgpool_pods"

    # Check replication status if pods are running
    if [ "$postgres_pods" -gt 0 ]; then
        print_status "Checking PostgreSQL replication status..."

        # Find the primary pod
        local primary_pod=$(kubectl get pods -n "$POSTGRES_NAMESPACE" -l app.kubernetes.io/component=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [ -n "$primary_pod" ]; then
            echo "Primary pod: $primary_pod"

            # Check replication slots (this might require password)
            print_status "To check replication manually, run:"
            echo "kubectl exec -n $POSTGRES_NAMESPACE $primary_pod -- psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"
        fi
    fi

    # Check secrets
    print_status "Checking PostgreSQL secrets..."
    kubectl get secrets -n "$POSTGRES_NAMESPACE" | grep postgresql || print_warning "No PostgreSQL secrets found"

    echo
}

# Function to check Redis
check_redis() {
    print_header "Redis HA Status"

    if ! check_namespace "$REDIS_NAMESPACE"; then
        print_error "Redis namespace '$REDIS_NAMESPACE' not found"
        return 1
    fi

    # Check Redis pods
    print_status "Checking Redis pods..."
    kubectl get pods -n "$REDIS_NAMESPACE" -o wide

    # Check services
    print_status "Checking Redis services..."
    kubectl get svc -n "$REDIS_NAMESPACE"

    # Check PVCs
    print_status "Checking Redis storage..."
    kubectl get pvc -n "$REDIS_NAMESPACE"

    # Check if master/replica/sentinel are running
    local master_pods=$(kubectl get pods -n "$REDIS_NAMESPACE" -l app.kubernetes.io/component=master --no-headers | grep -c "Running" || echo "0")
    local replica_pods=$(kubectl get pods -n "$REDIS_NAMESPACE" -l app.kubernetes.io/component=replica --no-headers | grep -c "Running" || echo "0")
    local sentinel_pods=$(kubectl get pods -n "$REDIS_NAMESPACE" -l app.kubernetes.io/component=sentinel --no-headers | grep -c "Running" || echo "0")

    print_status "Redis master pods running: $master_pods"
    print_status "Redis replica pods running: $replica_pods"
    print_status "Redis sentinel pods running: $sentinel_pods"

    # Check sentinel status if available
    if [ "$sentinel_pods" -gt 0 ]; then
        local sentinel_pod=$(kubectl get pods -n "$REDIS_NAMESPACE" -l app.kubernetes.io/component=sentinel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [ -n "$sentinel_pod" ]; then
            print_status "Checking Redis Sentinel status..."
            echo "Sentinel pod: $sentinel_pod"
            echo "To check sentinel status manually, run:"
            echo "kubectl exec -n $REDIS_NAMESPACE $sentinel_pod -- redis-cli -p 26379 sentinel masters"
        fi
    fi

    # Check secrets
    print_status "Checking Redis secrets..."
    kubectl get secrets -n "$REDIS_NAMESPACE" | grep redis || print_warning "No Redis secrets found"

    echo
}

# Function to check Vault connectivity
check_vault() {
    print_header "Vault Connectivity Check"

    if ! check_namespace "$VAULT_NAMESPACE"; then
        print_error "Vault namespace '$VAULT_NAMESPACE' not found"
        return 1
    fi

    # Check Vault pods
    print_status "Checking Vault pods..."
    kubectl get pods -n "$VAULT_NAMESPACE" -o wide

    # Check if Vault is unsealed
    local vault_pod=$(kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$vault_pod" ]; then
        print_status "Checking Vault status..."
        if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- vault status 2>/dev/null; then
            print_success "Vault is accessible"
        else
            print_warning "Vault status check failed (might be sealed or not ready)"
        fi

        # Check if database secrets exist
        print_status "Checking database secrets in Vault..."
        if kubectl exec -n "$VAULT_NAMESPACE" "$vault_pod" -- vault kv list secret/database 2>/dev/null; then
            print_success "Database secrets path accessible"
        else
            print_warning "Cannot access database secrets (check authentication)"
        fi
    fi

    echo
}

# Function to check overall health
check_overall_health() {
    print_header "Overall Health Summary"

    local postgres_healthy=false
    local redis_healthy=false
    local eso_healthy=false
    local vault_healthy=false

    # Check PostgreSQL
    if check_namespace "$POSTGRES_NAMESPACE"; then
        local postgres_pods=$(kubectl get pods -n "$POSTGRES_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
        if [ "$postgres_pods" -gt 0 ]; then
            postgres_healthy=true
            print_success "PostgreSQL: HEALTHY ($postgres_pods pods running)"
        else
            print_error "PostgreSQL: UNHEALTHY (no running pods)"
        fi
    else
        print_error "PostgreSQL: NOT DEPLOYED"
    fi

    # Check Redis
    if check_namespace "$REDIS_NAMESPACE"; then
        local redis_pods=$(kubectl get pods -n "$REDIS_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
        if [ "$redis_pods" -gt 0 ]; then
            redis_healthy=true
            print_success "Redis: HEALTHY ($redis_pods pods running)"
        else
            print_error "Redis: UNHEALTHY (no running pods)"
        fi
    else
        print_error "Redis: NOT DEPLOYED"
    fi

    # Check External Secrets
    if check_namespace "$ESO_NAMESPACE"; then
        local eso_pods=$(kubectl get pods -n "$ESO_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
        if [ "$eso_pods" -gt 0 ]; then
            eso_healthy=true
            print_success "External Secrets: HEALTHY ($eso_pods pods running)"
        else
            print_error "External Secrets: UNHEALTHY (no running pods)"
        fi
    else
        print_error "External Secrets: NOT DEPLOYED"
    fi

    # Check Vault
    if check_namespace "$VAULT_NAMESPACE"; then
        local vault_pods=$(kubectl get pods -n "$VAULT_NAMESPACE" --no-headers | grep -c "Running" || echo "0")
        if [ "$vault_pods" -gt 0 ]; then
            vault_healthy=true
            print_success "Vault: HEALTHY ($vault_pods pods running)"
        else
            print_error "Vault: UNHEALTHY (no running pods)"
        fi
    else
        print_error "Vault: NOT DEPLOYED"
    fi

    echo
    if $postgres_healthy && $redis_healthy && $eso_healthy && $vault_healthy; then
        print_success "ALL SYSTEMS HEALTHY"
        return 0
    else
        print_warning "SOME SYSTEMS NEED ATTENTION"
        return 1
    fi
}

# Function to show logs
show_logs() {
    local component=$1
    local namespace=""
    local selector=""

    case $component in
        postgresql|postgres)
            namespace="$POSTGRES_NAMESPACE"
            selector="app.kubernetes.io/name=postgresql-ha"
            ;;
        redis)
            namespace="$REDIS_NAMESPACE"
            selector="app.kubernetes.io/name=redis"
            ;;
        eso|external-secrets)
            namespace="$ESO_NAMESPACE"
            selector="app.kubernetes.io/name=external-secrets"
            ;;
        vault)
            namespace="$VAULT_NAMESPACE"
            selector="app.kubernetes.io/name=vault"
            ;;
        *)
            print_error "Unknown component: $component"
            print_status "Available components: postgresql, redis, external-secrets, vault"
            return 1
            ;;
    esac

    print_header "Recent logs for $component"
    kubectl logs -n "$namespace" -l "$selector" --tail=50 --prefix=true
}

# Function to show usage
show_usage() {
    echo "Database Health Check Script"
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  check          - Run all health checks (default)"
    echo "  postgresql     - Check PostgreSQL only"
    echo "  redis          - Check Redis only"
    echo "  vault          - Check Vault only"
    echo "  external-secrets - Check External Secrets Operator only"
    echo "  overall        - Show overall health summary"
    echo "  logs <component> - Show recent logs for component"
    echo "  help           - Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Run all checks"
    echo "  $0 postgresql         # Check PostgreSQL only"
    echo "  $0 logs redis         # Show Redis logs"
}

# Main function
main() {
    local command=${1:-check}

    case $command in
        check)
            check_external_secrets
            check_vault
            check_postgresql
            check_redis
            check_overall_health
            ;;
        postgresql|postgres)
            check_postgresql
            ;;
        redis)
            check_redis
            ;;
        vault)
            check_vault
            ;;
        external-secrets|eso)
            check_external_secrets
            ;;
        overall)
            check_overall_health
            ;;
        logs)
            if [ $# -lt 2 ]; then
                print_error "logs command requires a component name"
                show_usage
                exit 1
            fi
            show_logs "$2"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is required but not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Run main function
main "$@"
