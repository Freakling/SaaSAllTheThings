resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'shop-bus'
  location: resourceGroup().location
  sku: { name: 'Standard', tier: 'Standard' }
  properties: { disableLocalAuth: true }
}
