@description('The location for the data factory')
param location string

@description('The name of the data factory')
param factoryName string

// Create Data Factory
resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    purviewConfiguration: {
      purviewResourceId: null
    }
  }
}

// Create Git Configuration (optional - uncomment and modify as needed)
/*
resource factoryGitConfig 'Microsoft.DataFactory/factories/gitConfigurations@2018-06-01' = {
  parent: factory
  name: 'default'
  properties: {
    hostName: 'https://github.com'
    repoConfiguration: {
      accountName: 'your-github-account'
      repositoryName: 'your-repo-name'
      collaborationBranch: 'main'
      rootFolder: '/adf_pipelines'
      type: 'FactoryGitHubConfiguration'
    }
    type: 'GitHub'
  }
}
*/

// Create Managed Virtual Network
resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: factory
  name: 'default'
  properties: {}
}

// Create Auto Resolve Integration Runtime
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: factory
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      referenceName: managedVnet.name
      type: 'ManagedVirtualNetworkReference'
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

// Outputs
output factoryName string = factory.name
output factoryId string = factory.id
output principalId string = factory.identity.principalId 