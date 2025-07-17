#!/bin/bash

set -euo pipefail

echo "🔐 Setting up Authentik secrets in Vault..."

# Configuration
VAULT_NAMESPACE="vault-system"
VAULT_POD="vault-system-vault-0"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if Vault pod is running
echo "📋 Checking Vault deployment..."
if ! kubectl get pod -n "${VAULT_NAMESPACE}" "${VAULT_POD}" | grep -q Running; then
    echo "❌ Vault pod ${VAULT_POD} is not running in namespace ${VAULT_NAMESPACE}"
    exit 1
fi

echo "✅ Found Vault pod: ${VAULT_POD}"

# Get Vault root token
if [ -z "${VAULT_TOKEN:-}" ]; then
    # Check for token file in home directory
    if [ -f "$HOME/.vault-root-token" ]; then
        ROOT_TOKEN=$(cat "$HOME/.vault-root-token")
        echo "✅ Found Vault root token in ~/.vault-root-token"
    else
        echo "🔐 Please provide your Vault root token:"
        echo "💡 You can find it in your Vault initialization output or ~/.vault-root-token"
        read -s -p "Vault Root Token: " ROOT_TOKEN
        echo ""
    fi
else
    ROOT_TOKEN="${VAULT_TOKEN}"
    echo "✅ Using VAULT_TOKEN environment variable"
fi

# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "🔑 Generated secure PostgreSQL password"

SECRET_KEY=$(openssl rand -base64 64)
echo "🔑 Generated secure Authentik secret key"

# Enable KV v2 secrets engine if not already enabled
echo "🔧 Ensuring KV secrets engine is enabled..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault secrets list | grep -q "secret/" || {
    kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault secrets enable -path=secret kv-v2
    echo "✅ KV secrets engine enabled at secret/"
}

# Create the secrets in Vault
echo "📝 Creating Authentik PostgreSQL secret in Vault..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault kv put secret/authentik-postgres \
    username=authentik \
    password="${POSTGRES_PASSWORD}"

echo "📝 Creating Authentik secret key in Vault..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault kv put secret/authentik \
    secret_key="${SECRET_KEY}"

# Enable Kubernetes auth if not already enabled
echo "🔧 Configuring Vault Kubernetes authentication..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault auth list | grep -q kubernetes || {
    kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault auth enable kubernetes
    echo "✅ Kubernetes auth method enabled"
}

# Configure Kubernetes auth
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert="@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

echo "✅ Kubernetes auth configured"

# Update policy for External Secrets Operator
echo "📜 Updating Vault policy for External Secrets Operator..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" sh -c '
vault policy write external-secrets - <<EOF
path "secret/data/postgres" {
  capabilities = ["read"]
}
path "secret/data/authentik-postgres" {
  capabilities = ["read"]
}
path "secret/data/authentik" {
  capabilities = ["read"]
}
EOF
'

echo "✅ Policy 'external-secrets' updated"

# Create role for External Secrets Operator
echo "👤 Creating Vault role for External Secrets Operator..."
kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets-system-external-secrets \
    bound_service_account_namespaces=external-secrets-system \
    policies=external-secrets \
    ttl=24h

echo "✅ Role 'external-secrets' created"

# Verify the secrets were created
echo "🔍 Verifying secret creation..."
if kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault kv get secret/authentik-postgres > /dev/null 2>&1 && \
   kubectl exec -n "${VAULT_NAMESPACE}" "${VAULT_POD}" -- env VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="${ROOT_TOKEN}" vault kv get secret/authentik > /dev/null 2>&1; then
    echo "✅ Secret verification successful"
else
    echo "❌ Secret verification failed"
    exit 1
fi

echo ""
echo "🎉 Authentik Vault setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "  • PostgreSQL username: authentik"
echo "  • PostgreSQL password: ${POSTGRES_PASSWORD}"
echo "  • Vault path for PostgreSQL: secret/authentik-postgres"
echo "  • Authentik secret key: ${SECRET_KEY}"
echo "  • Vault path for secret key: secret/authentik"
echo "  • Kubernetes auth configured for ESO"
echo ""
echo "🚀 You can now deploy your Authentik instance!"
echo "   The External Secrets Operator will automatically fetch"
echo "   the credentials from Vault and create the required secrets."
