using './main.bicep'

// The resource name comes from the SWA_NAME repo variable (exported by GitHub Actions).
// The default is the current resource's real name, so what-if can run locally without exporting anything.
param name = readEnvironmentVariable('SWA_NAME', 'eortega-dev')

param location = 'centralus' // where the real resource lives; cannot change without recreating it
param sku = 'Free'

param customDomains = [
  'eortega.dev'
]

param tags = {
  project: 'eortega-dev'
  managedBy: 'bicep'
}
