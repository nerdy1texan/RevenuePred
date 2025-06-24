@description('The location for the static web app')
param location string

@description('The name of the static web app')
param name string

@description('The SKU for the static web app')
param sku object = {
  name: 'Free'
  tier: 'Free'
}

// Create Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2021-03-01' = {
  name: name
  location: location
  sku: sku
  properties: {
    provider: 'GitHub'
    buildProperties: {
      skipGithubActionWorkflowGeneration: true
    }
    allowConfigFileUpdates: true
  }
}

// Create Custom Domain (optional - uncomment and modify as needed)
/*
resource customDomain 'Microsoft.Web/staticSites/customDomains@2021-03-01' = {
  parent: staticWebApp
  name: 'your-domain.com'
  properties: {}
}
*/

// Outputs
output name string = staticWebApp.name
output defaultHostname string = staticWebApp.properties.defaultHostname
output id string = staticWebApp.id 