@description('The location for the workspace')
param location string

@description('The name of the workspace')
param workspaceName string

@description('The name of the associated Application Insights instance')
param applicationInsightsName string

@description('The ID of the storage account to use')
param storageAccountId string

// Create Key Vault for AML workspace
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: 'kv-${take(replace(workspaceName, '-', ''), 20)}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Create Container Registry for AML workspace
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: replace('cr${workspaceName}', '-', '')
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Create Machine Learning Workspace
resource workspace 'Microsoft.MachineLearningServices/workspaces@2022-05-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: workspaceName
    storageAccount: storageAccountId
    keyVault: keyVault.id
    applicationInsights: resourceId('Microsoft.Insights/components', applicationInsightsName)
    containerRegistry: containerRegistry.id
    publicNetworkAccess: 'Enabled'
    v1LegacyMode: false
  }
}

// Create Compute Cluster
resource computeCluster 'Microsoft.MachineLearningServices/workspaces/computes@2022-05-01' = {
  parent: workspace
  name: 'cpu-cluster'
  location: location
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: 'Standard_DS3_v2'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 4
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
      remoteLoginPortPublicAccess: 'Disabled'
    }
  }
}

// Outputs
output workspaceName string = workspace.name
output computeClusterName string = computeCluster.name 