#!/usr/bin/env bash
# Publishes the Terraform outputs as GitHub repository variables so the CD workflow knows
# which registry, cluster and Key Vault to use. Run after the first successful `terraform apply`.
#
# Requires: terraform (initialised in terraform/environments/dev), GitHub CLI logged in.

set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-sreepradat/azure-aks-platform-engineering}"
TF_DIR="${TF_DIR:-terraform/environments/dev}"

outputs="$(terraform -chdir="${TF_DIR}" output -json)"

get() {
  python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]]["value"])' "$1" <<<"${outputs}"
}

set_var() {
  local name="$1" value="$2"
  gh variable set "${name}" --repo "${GITHUB_REPO}" --body "${value}"
  echo "Set ${name}=${value}"
}

set_var RESOURCE_GROUP "$(get resource_group_name)"
set_var AKS_NAME "$(get aks_name)"
set_var ACR_NAME "$(get acr_name)"
set_var KEY_VAULT_NAME "$(get key_vault_name)"
set_var WORKLOAD_IDENTITY_CLIENT_ID "$(get workload_identity_client_id)"

echo
echo "Done. Push a change under app/ or helm/ (or run the CD workflow manually) to deploy."
