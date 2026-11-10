#!/usr/bin/env bash
# One-time bootstrap (or full rebuild from scratch) of what Bicep does NOT manage:
#   1. Resource group
#   2. GitHub Actions identity (app registration + OIDC federated credentials, no secrets)
#   3. Contributor role for that identity, scoped ONLY to the resource group
#   4. GitHub repo variables (AZURE_CLIENT_ID, AZURE_TENANT_ID, ...)
#
# Requirements: `az login` with the PERSONAL account (not the ULatina one) and `gh auth login` as e-ortega.
# Idempotent: running it twice does not duplicate anything.
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash on Windows: don't convert "/subscriptions/..." into disk paths
# Windows az emits CRLF: without this, every $(az ...) carries a trailing \r ("true\r", "<appId>\r").
az() { command az "$@" | tr -d '\r'; }
# Git Bash launched from PowerShell doesn't always have gh on the PATH.
command -v gh >/dev/null || export PATH="$PATH:/c/Program Files/GitHub CLI"
command -v gh >/dev/null || { echo "gh (GitHub CLI) not found on PATH"; exit 1; }

REPO="e-ortega/eortega-dev"
RG="eortega-dev"
LOCATION="centralus" # only used if the RG doesn't exist; an existing RG's region cannot change
APP_NAME="github-actions-eortega-dev"

echo "== Active az subscription =="
az account show --query "{name:name, id:id, user:user.name, tenant:tenantDefaultDomain}" -o table
read -r -p "Is this the PERSONAL (Pay-As-You-Go) subscription? [y/N] " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || { echo "Aborted. Use: az account set --subscription <id>"; exit 1; }

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
RG_ID="/subscriptions/$SUB_ID/resourceGroups/$RG"

echo "== Resource group =="
if [[ "$(az group exists --name "$RG")" == "true" ]]; then
  echo "Already exists: $RG ($(az group show --name "$RG" --query location -o tsv))"
else
  az group create --name "$RG" --location "$LOCATION" --tags project=eortega-dev managedBy=bootstrap -o none
  echo "Created: $RG ($LOCATION)"
fi

echo "== Existing Static Web App =="
SWA_NAME=$(az staticwebapp list -g "$RG" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -n "$SWA_NAME" ]]; then
  echo "Found: $SWA_NAME (Bicep will adopt this resource)"
else
  SWA_NAME="eortega-dev"
  echo "None found; Bicep will create a new one named: $SWA_NAME"
fi

echo "== App registration =="
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [[ -z "$APP_ID" ]]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "Created: $APP_ID"
else
  echo "Already exists: $APP_ID"
fi
az ad sp show --id "$APP_ID" -o none 2>/dev/null || az ad sp create --id "$APP_ID" -o none

echo "== Federated credentials (OIDC) =="
add_cred() { # name subject
  local params="{
      \"name\": \"$1\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$2\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }"
  local current
  current=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$1'] | [0].subject" -o tsv)
  if [[ -z "$current" ]]; then
    az ad app federated-credential create --id "$APP_ID" -o none --parameters "$params"
    echo "Created: $1 -> $2"
  elif [[ "$current" != "$2" ]]; then
    az ad app federated-credential update --id "$APP_ID" --federated-credential-id "$1" -o none --parameters "$params"
    echo "Updated: $1 -> $2 (was: $current)"
  else
    echo "Already exists: $1 -> $2"
  fi
}
# The subject prefix depends on the repo's OIDC settings: this repo uses immutable subjects
# ("repo:e-ortega@<owner_id>/eortega-dev@<repo_id>"), not the classic "repo:e-ortega/eortega-dev".
SUB_PREFIX=$(gh api "repos/$REPO/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty' 2>/dev/null || true)
SUB_PREFIX="${SUB_PREFIX:-repo:$REPO}"
echo "OIDC subject prefix: $SUB_PREFIX"
add_cred "main-branch"  "$SUB_PREFIX:ref:refs/heads/main"
add_cred "pull-request" "$SUB_PREFIX:pull_request"

echo "== Contributor role on the RG (RG only) =="
if az role assignment list --assignee "$APP_ID" --scope "$RG_ID" --role Contributor --query "[0].id" -o tsv | grep -q .; then
  echo "Already exists"
else
  # Right after creating the SP, Entra sometimes takes a while to propagate it: retry.
  for i in 1 2 3 4 5; do
    az role assignment create --assignee "$APP_ID" --role Contributor --scope "$RG_ID" -o none && break
    echo "Retrying in 10s..."; sleep 10
  done
fi

echo "== GitHub repo variables =="
gh variable set AZURE_CLIENT_ID       --repo "$REPO" --body "$APP_ID"
gh variable set AZURE_TENANT_ID       --repo "$REPO" --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --repo "$REPO" --body "$SUB_ID"
gh variable set AZURE_RESOURCE_GROUP  --repo "$REPO" --body "$RG"
gh variable set SWA_NAME              --repo "$REPO" --body "$SWA_NAME"

echo
echo "Done. Next step: run what-if before the first deploy:"
echo "  SWA_NAME=$SWA_NAME az deployment group what-if -g $RG --parameters infra/main.bicepparam"
