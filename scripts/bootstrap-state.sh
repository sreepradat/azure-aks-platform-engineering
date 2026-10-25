#!/usr/bin/env bash
# Creates the Azure Storage account that holds the Terraform remote state.
# Run once, before the first `terraform init`. Safe to re-run.
#
# Requires: Azure CLI, logged in (`az login`) with rights to create resources.

set -euo pipefail

LOCATION="${LOCATION:-centralindia}"
PROJECT="${PROJECT:-aksplat}"
RESOURCE_GROUP="${TFSTATE_RESOURCE_GROUP:-rg-tfstate-${PROJECT}}"
CONTAINER="${TFSTATE_CONTAINER:-tfstate}"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# Deterministic suffix: re-running the script finds the same storage account.
SUFFIX="$(printf '%s' "${SUBSCRIPTION_ID}" | sha256sum | cut -c1-6)"
STORAGE_ACCOUNT="${TFSTATE_STORAGE_ACCOUNT:-sttfstate${PROJECT}${SUFFIX}}"

echo "Subscription : ${SUBSCRIPTION_ID}"
echo "Location     : ${LOCATION}"
echo "State RG     : ${RESOURCE_GROUP}"
echo "Storage acct : ${STORAGE_ACCOUNT}"
echo

az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

if ! az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  az storage account create \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none
fi

# Keep history of the state file so a bad apply can be rolled back.
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --output none

# Grant the current user data-plane access so Azure AD auth works for the backend.
USER_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
STORAGE_ID="$(az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)"
az role assignment create \
  --assignee-object-id "${USER_OBJECT_ID}" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "${STORAGE_ID}" \
  --output none || true

echo "Waiting for the role assignment to propagate..."
sleep 30

az storage container create \
  --name "${CONTAINER}" \
  --account-name "${STORAGE_ACCOUNT}" \
  --auth-mode login \
  --output none

cat <<EOF

Remote state is ready. Use these values:

  TFSTATE_RESOURCE_GROUP  = ${RESOURCE_GROUP}
  TFSTATE_STORAGE_ACCOUNT = ${STORAGE_ACCOUNT}
  TFSTATE_CONTAINER       = ${CONTAINER}

Next:
  1. cp terraform/environments/dev/backend.hcl.example terraform/environments/dev/backend.hcl
     and put the values above into it.
  2. export TFSTATE_RESOURCE_GROUP=${RESOURCE_GROUP} TFSTATE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT} TFSTATE_CONTAINER=${CONTAINER}
     then run ./scripts/setup-github-oidc.sh
EOF
