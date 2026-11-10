// Infraestructura del frontend de eortega.dev: Azure Static Web App (+ dominios custom).
// Scope: resource group. El RG y la identidad de despliegue se crean una sola vez con
// infra/bootstrap.sh; este template solo maneja lo que vive DENTRO del RG, para que la
// identidad de GitHub Actions no necesite permisos a nivel de suscripción (es PAYG).
targetScope = 'resourceGroup'

@description('Nombre del recurso Static Web App (no el hostname *.azurestaticapps.net).')
param name string

@description('Regiones donde Static Web Apps existe como plataforma.')
@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'westeurope'
  'eastasia'
])
param location string = 'centralus'

@description('Free = $0. Standard tiene costo mensual: no cambiar sin decidirlo explícitamente.')
@allowed([
  'Free'
  'Standard'
])
param sku string = 'Free'

@description('Dominios custom. Un dominio raíz (ej. eortega.dev) se valida con TXT; un subdominio con CNAME.')
param customDomains array = []

param tags object = {}

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled' // previews por PR (el tier Free permite hasta 3)
    allowConfigFileUpdates: true
    // Intencionalmente sin repositoryUrl/branch: el recurso no queda atado al repo desde el portal
    // (se desconectó con `az staticwebapp disconnect`). No se declara deploymentAuthPolicy: Azure
    // rechaza cambiarla sin un PAT de GitHub ("Cannot update policy without providing repository
    // token"), así que queda la que tenga el recurso; frontend.yml manda token + github_id_token.
  }
}

// De a uno: las operaciones de dominio del mismo Static Web App chocan si corren en paralelo.
@batchSize(1)
resource domains 'Microsoft.Web/staticSites/customDomains@2023-12-01' = [
  for domain in customDomains: {
    parent: swa
    name: domain
    properties: {
      // Heurística simple de "es raíz": dos etiquetas (eortega.dev). No cubre TLDs tipo .co.cr.
      validationMethod: length(split(domain, '.')) == 2 ? 'dns-txt-token' : 'cname-delegation'
    }
  }
]

output name string = swa.name
output defaultHostname string = swa.properties.defaultHostname
