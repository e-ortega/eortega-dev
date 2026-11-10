#!/usr/bin/env bash
# Bootstrap de una sola vez (o para recrear desde cero) de lo que Bicep NO maneja:
#   1. Resource group
#   2. Identidad de GitHub Actions (app registration + federated credentials OIDC, sin secretos)
#   3. Rol Contributor de esa identidad SOLO sobre el resource group
#   4. Variables del repo en GitHub (AZURE_CLIENT_ID, AZURE_TENANT_ID, ...)
#
# Requisitos: `az login` con la cuenta PERSONAL (no la de ULatina) y `gh auth login` como e-ortega.
# Es idempotente: correrlo dos veces no duplica nada.
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash en Windows: no convertir "/subscriptions/..." en rutas de disco
# El az de Windows emite CRLF: sin esto cada $(az ...) trae un \r pegado ("true\r", "<appId>\r").
az() { command az "$@" | tr -d '\r'; }

REPO="e-ortega/eortega-dev"
RG="eortega-dev"
LOCATION="centralus" # solo se usa si el RG no existe; la región de un RG existente no se puede cambiar
APP_NAME="github-actions-eortega-dev"

echo "== Suscripción activa de az =="
az account show --query "{name:name, id:id, user:user.name, tenant:tenantDefaultDomain}" -o table
read -r -p "¿Es la suscripción PERSONAL (Pay-As-You-Go)? [s/N] " ok
[[ "$ok" == "s" || "$ok" == "S" ]] || { echo "Abortado. Usa: az account set --subscription <id>"; exit 1; }

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
RG_ID="/subscriptions/$SUB_ID/resourceGroups/$RG"

echo "== Resource group =="
if [[ "$(az group exists --name "$RG")" == "true" ]]; then
  echo "Ya existía: $RG ($(az group show --name "$RG" --query location -o tsv))"
else
  az group create --name "$RG" --location "$LOCATION" --tags project=eortega-dev managedBy=bootstrap -o none
  echo "Creado: $RG ($LOCATION)"
fi

echo "== Static Web App existente =="
SWA_NAME=$(az staticwebapp list -g "$RG" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -n "$SWA_NAME" ]]; then
  echo "Encontrado: $SWA_NAME (Bicep va a adoptar este recurso)"
else
  SWA_NAME="eortega-dev"
  echo "No hay ninguno; Bicep va a crear uno nuevo llamado: $SWA_NAME"
fi

echo "== App registration =="
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [[ -z "$APP_ID" ]]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "Creada: $APP_ID"
else
  echo "Ya existía: $APP_ID"
fi
az ad sp show --id "$APP_ID" -o none 2>/dev/null || az ad sp create --id "$APP_ID" -o none

echo "== Federated credentials (OIDC) =="
add_cred() { # nombre subject
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$1'] | [0].name" -o tsv | grep -q .; then
    echo "Ya existía: $1"
  else
    az ad app federated-credential create --id "$APP_ID" -o none --parameters "{
      \"name\": \"$1\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$2\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }"
    echo "Creada: $1 -> $2"
  fi
}
add_cred "main-branch"  "repo:$REPO:ref:refs/heads/main"
add_cred "pull-request" "repo:$REPO:pull_request"

echo "== Rol Contributor sobre el RG (solo el RG) =="
if az role assignment list --assignee "$APP_ID" --scope "$RG_ID" --role Contributor --query "[0].id" -o tsv | grep -q .; then
  echo "Ya existía"
else
  # Recién creado el SP, Entra a veces tarda en propagarlo: reintentar.
  for i in 1 2 3 4 5; do
    az role assignment create --assignee "$APP_ID" --role Contributor --scope "$RG_ID" -o none && break
    echo "Reintentando en 10s..."; sleep 10
  done
fi

echo "== Variables del repo en GitHub =="
gh variable set AZURE_CLIENT_ID       --repo "$REPO" --body "$APP_ID"
gh variable set AZURE_TENANT_ID       --repo "$REPO" --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --repo "$REPO" --body "$SUB_ID"
gh variable set AZURE_RESOURCE_GROUP  --repo "$REPO" --body "$RG"
gh variable set SWA_NAME              --repo "$REPO" --body "$SWA_NAME"

echo
echo "Listo. Siguiente paso: correr what-if antes del primer deploy:"
echo "  SWA_NAME=$SWA_NAME az deployment group what-if -g $RG --parameters infra/main.bicepparam"
