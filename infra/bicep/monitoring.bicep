@description('The location for Application Insights')
param location string

@description('The name of the Application Insights instance')
param appInsightsName string

@description('Daily data cap in GB. Default is 1GB')
param dailyQuotaGb int = 1

// Create Log Analytics workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${appInsightsName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
  }
}

// Create Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Create Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' = {
  name: 'ag-${appInsightsName}'
  location: 'global'
  properties: {
    groupShortName: 'MLPipeline'
    enabled: true
    emailReceivers: [
      {
        name: 'emailAction'
        emailAddress: 'admin@abcrenewables.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Outputs
output appInsightsName string = appInsights.name
output appInsightsId string = appInsights.id
output instrumentationKey string = appInsights.properties.InstrumentationKey 