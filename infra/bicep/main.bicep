@description('The location for all resources')
param location string = resourceGroup().location

@description('The location for Static Web Apps (must be one of: westus2,centralus,eastus2,westeurope,eastasia)')
param staticWebAppLocation string = 'eastus2'

@description('Environment name (e.g., prod, dev)')
param environmentName string = 'prod'

@description('Project name used in resource naming')
param projectName string = 'abcrenewables'

// Variables for resource naming
var storageAccountName = 'st${projectName}${environmentName}'
var dataFactoryName = 'adf-${projectName}-${environmentName}'
var amlWorkspaceName = 'aml-${projectName}-${environmentName}'
var appInsightsName = 'appi-${projectName}-${environmentName}'
var staticWebAppName = 'swa-${projectName}-${environmentName}'

// Storage Account (Data Lake Gen2)
module storage './storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// Application Insights (must be created before AML workspace)
module monitoring './monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    location: location
    appInsightsName: appInsightsName
  }
}

// Azure ML Workspace (depends on Application Insights)
module amlWorkspace './aml.bicep' = {
  name: 'amlDeployment'
  params: {
    location: location
    workspaceName: amlWorkspaceName
    applicationInsightsName: appInsightsName
    storageAccountId: storage.outputs.storageAccountId
  }
  dependsOn: [
    monitoring
  ]
}

// Azure Data Factory
module dataFactory './adf.bicep' = {
  name: 'adfDeployment'
  params: {
    location: location
    factoryName: dataFactoryName
  }
}

// Static Web App
module staticWebApp './swa.bicep' = {
  name: 'swaDeployment'
  params: {
    location: staticWebAppLocation
    name: staticWebAppName
  }
}

// Outputs
output storageAccountName string = storage.outputs.storageAccountName
output dataFactoryName string = dataFactory.outputs.factoryName
output amlWorkspaceName string = amlWorkspace.outputs.workspaceName
output staticWebAppName string = staticWebApp.outputs.name
output appInsightsName string = monitoring.outputs.appInsightsName 