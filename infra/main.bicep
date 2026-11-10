// Frontend infrastructure for eortega.dev: Azure Static Web App (+ custom domains).
// Scope: resource group. The RG and the deployment identity are created once by
// infra/bootstrap.sh; this template only manages what lives INSIDE the RG, so the
// GitHub Actions identity never needs subscription-level permissions (it's Pay-As-You-Go).
targetScope = 'resourceGroup'

@description('Static Web App resource name (not the *.azurestaticapps.net hostname).')
param name string

@description('Regions where Static Web Apps is available as a platform.')
@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'westeurope'
  'eastasia'
])
param location string = 'centralus'

@description('Free = $0. Standard has a monthly cost: do not change without an explicit decision.')
@allowed([
  'Free'
  'Standard'
])
param sku string = 'Free'

@description('Custom domains. An apex domain (e.g. eortega.dev) is validated via TXT; a subdomain via CNAME.')
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
    stagingEnvironmentPolicy: 'Enabled' // per-PR previews (the Free tier allows up to 3)
    allowConfigFileUpdates: true
    // Intentionally no repositoryUrl/branch: the resource is not linked to the repo through the
    // portal (it was detached with `az staticwebapp disconnect`).
    // deploymentAuthPolicy is not declared: ARM only allows changing it with a GitHub PAT plus
    // buildProperties. It was set to 'DeploymentToken' once, manually (see CLAUDE.md). A NEW
    // resource created by this template has no repo link, so it uses token auth by default.
  }
}

// One at a time: custom domain operations on the same Static Web App conflict when run in parallel.
@batchSize(1)
resource domains 'Microsoft.Web/staticSites/customDomains@2023-12-01' = [
  for domain in customDomains: {
    parent: swa
    name: domain
    properties: {
      // Simple "is apex" heuristic: two labels (eortega.dev). Does not handle TLDs like .co.cr.
      validationMethod: length(split(domain, '.')) == 2 ? 'dns-txt-token' : 'cname-delegation'
    }
  }
]

output name string = swa.name
output defaultHostname string = swa.properties.defaultHostname
