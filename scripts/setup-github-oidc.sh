#!/usr/bin/env bash
# Lets GitHub Actions authenticate to Azure with OpenID Connect (no client secret stored anywhere).
#
# Creates:
#   - a Microsoft Entra app registration + service principal
#   - federated credentials for: pull requests, the main branch, and the "dev" environment
#   - role assignments the pipelines need
#   - the GitHub repository variables used by the workflows (when GitHub CLI is logged in)
#
# Requires: Azure CLI (`az login`), GitHub CLI (`gh auth login`) for the variables step.
# Needs permission to create app registrations and to assign roles on the subscription.
#
# Usage:
#   export TFSTATE_RESOURCE_GROUP=... TFSTATE_STORAGE_ACCOUNT=... TFSTATE_CONTAINER=tfstate
#   GITHUB_REPO=<owner>/<repo> ./scripts/setup-github-oidc.sh

set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-sreepradat/azure-aks-platform-engineering}"
APP_NAME="${APP_NAME:-gh-aksplat-${GITHUB_REPO//\//-}}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"

: "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP (printed by bootstrap-state.sh)}"
: "${TFSTATE_STORAGE_ACCOUNT:?Set TFSTATE_STORAGE_ACCOUNT (printed by bootstrap-state.sh)}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-tfstate}"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "Repository   : ${GITHUB_REPO}"
echo "Subscription : ${SUBSCRIPTION_ID}"
echo "App name     : ${APP_NAME}"
echo

# --- App registration and service principal (idempotent) ---
APP_ID="$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)"
if [[ -z "${APP_ID}" ]]; then
  APP_ID="$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)"
  echo "Created app registration ${APP_ID}"
fi

if ! az ad sp show --id "${APP_ID}" --output none 2>/dev/null; then
  az ad sp create --id "${APP_ID}" --output none
  echo "Created service principal"
fi
SP_OBJECT_ID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)"

# --- Federated credentials: which GitHub workflow contexts may sign in ---
create_credential() {
  local name="$1" subject="$2"
  if az ad app federated-credential list --id "${APP_ID}" --query "[?name=='${name}'].name" -o tsv | grep -q .; then
    echo "Federated credential ${name} already exists"
    return
  fi
  local params
  params="$(mktemp)"
  cat >"${params}" <<EOF
{
  "name": "${name}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${subject}",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
  az ad app federated-credential create --id "${APP_ID}" --parameters "${params}" --output none
  rm -f "${params}"
  echo "Created federated credential ${name} (${subject})"
}

create_credential "github-pull-request" "repo:${GITHUB_REPO}:pull_request"
create_credential "github-main-branch" "repo:${GITHUB_REPO}:ref:refs/heads/main"
create_credential "github-env-${ENVIRONMENT_NAME}" "repo:${GITHUB_REPO}:environment:${ENVIRONMENT_NAME}"

# --- Role assignments ---
SUBSCRIPTION_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STORAGE_ID="$(az storage account show --name "${TFSTATE_STORAGE_ACCOUNT}" --resource-group "${TFSTATE_RESOURCE_GROUP}" --query id -o tsv)"

assign_role() {
  local role="$1" scope="$2"
  az role assignment create \
    --assignee-object-id "${SP_OBJECT_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "${role}" \
    --scope "${scope}" \
    --output none 2>/dev/null || true
  echo "Ensured role '${role}' on ${scope##*/}"
}

# Contributor creates the resources; User Access Administrator lets Terraform create the
# role assignments in the modules (AcrPull, Key Vault roles). For production, scope these to a
# resource group or use a conditioned "Role Based Access Control Administrator" instead.
assign_role "Contributor" "${SUBSCRIPTION_SCOPE}"
assign_role "User Access Administrator" "${SUBSCRIPTION_SCOPE}"
assign_role "Storage Blob Data Contributor" "${STORAGE_ID}"

# --- GitHub repository variables (not secrets: none of these values are sensitive) ---
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh variable set AZURE_CLIENT_ID --repo "${GITHUB_REPO}" --body "${APP_ID}"
  gh variable set AZURE_TENANT_ID --repo "${GITHUB_REPO}" --body "${TENANT_ID}"
  gh variable set AZURE_SUBSCRIPTION_ID --repo "${GITHUB_REPO}" --body "${SUBSCRIPTION_ID}"
  gh variable set TFSTATE_RESOURCE_GROUP --repo "${GITHUB_REPO}" --body "${TFSTATE_RESOURCE_GROUP}"
  gh variable set TFSTATE_STORAGE_ACCOUNT --repo "${GITHUB_REPO}" --body "${TFSTATE_STORAGE_ACCOUNT}"
  gh variable set TFSTATE_CONTAINER --repo "${GITHUB_REPO}" --body "${TFSTATE_CONTAINER}"
  echo
  echo "GitHub repository variables set on ${GITHUB_REPO}."
else
  cat <<EOF

GitHub CLI not available or not logged in. Create these repository variables manually
(Settings > Secrets and variables > Actions > Variables):

  AZURE_CLIENT_ID          = ${APP_ID}
  AZURE_TENANT_ID          = ${TENANT_ID}
  AZURE_SUBSCRIPTION_ID    = ${SUBSCRIPTION_ID}
  TFSTATE_RESOURCE_GROUP   = ${TFSTATE_RESOURCE_GROUP}
  TFSTATE_STORAGE_ACCOUNT  = ${TFSTATE_STORAGE_ACCOUNT}
  TFSTATE_CONTAINER        = ${TFSTATE_CONTAINER}
EOF
fi

cat <<EOF

Also create a GitHub environment named "${ENVIRONMENT_NAME}" (Settings > Environments) and add
yourself as a required reviewer so every terraform apply and deployment needs an approval.

After the first terraform apply, run ./scripts/set-deploy-variables.sh to publish the
remaining variables (ACR name, cluster name, Key Vault name, ...).
EOF
