// SEEDED (tests/security/README.md): public network access on, local authentication left on (A05).
resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'shop-bus'
  location: resourceGroup().location
  sku: { name: 'Standard', tier: 'Standard' }
  properties: { publicNetworkAccess: 'Enabled' }
}
