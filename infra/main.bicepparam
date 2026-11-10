using './main.bicep'

// El nombre del recurso viene de la variable de repo SWA_NAME (GitHub Actions la exporta).
// Default = nombre real del recurso actual, para poder correr what-if local sin exportar nada.
param name = readEnvironmentVariable('SWA_NAME', 'eortega-dev')

param location = 'centralus' // donde está el recurso real; no se puede cambiar sin recrearlo
param sku = 'Free'

param customDomains = [
  'eortega.dev'
]

param tags = {
  project: 'eortega-dev'
  managedBy: 'bicep'
}
