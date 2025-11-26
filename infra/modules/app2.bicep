@description('Primary location for all resources')
param location string

@description('Name of the project/workload')
param projectName string

@description('Environment name')
param environmentName string

@description('Tags to apply to all resources')
param tags object

@description('Resource token for unique naming')
param resourceToken string

@description('Subnet ID for App Service integration')
param subnetId string

@description('Key Vault ID for storing secrets')
param keyVaultId string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Application Insights ID for monitoring')
param applicationInsightsId string

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Storage Account for App2
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${abbrs.storageAccount}${replace(projectName, '-', '')}app2${environmentName}${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: environmentName == 'prod' ? 'Standard_GRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// App Service Plan for App2
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${abbrs.appServicePlan}-app2-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: environmentName == 'prod' ? 'P1v3' : 'B1'
    tier: environmentName == 'prod' ? 'PremiumV3' : 'Basic'
  }
  properties: {
    reserved: false
  }
}

// Function App (Alternative to App Service for App2)
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${abbrs.functionApp}-app2-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      netFrameworkVersion: 'v8.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('${abbrs.functionApp}-app2-${projectName}-${environmentName}-${resourceToken}')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(applicationInsightsId, '2020-02-02').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference(applicationInsightsId, '2020-02-02').ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environmentName
        }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: '@Microsoft.KeyVault(VaultName=${last(split(keyVaultId, '/'))};SecretName=sql-connection-string)'
          type: 'SQLServer'
        }
        {
          name: 'CosmosConnection'
          connectionString: '@Microsoft.KeyVault(VaultName=${last(split(keyVaultId, '/'))};SecretName=cosmos-connection-string)'
          type: 'Custom'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Get reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: last(split(keyVaultId, '/'))
}

// Grant Function App access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2024-04-01-preview' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Virtual Network Integration for Function App
resource vnetIntegration 'Microsoft.Web/sites/networkConfig@2023-12-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: subnetId
    swiftSupported: true
  }
}

// Container Registry for containerized workloads
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: '${abbrs.containerRegistry}${replace(projectName, '-', '')}app2${environmentName}${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: environmentName == 'prod' ? 'Premium' : 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: environmentName == 'prod' ? 'Enabled' : 'Disabled'
  }
}

// Grant Function App access to Container Registry
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, functionApp.id, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings for Function App
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Diagnostic settings for Storage Account
resource storageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Diagnostic settings for Container Registry
resource containerRegistryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: containerRegistry
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
@description('Function App ID')
output functionAppId string = functionApp.id

@description('Function App Name')
output functionAppName string = functionApp.name

@description('App Service Plan ID')
output appServicePlanId string = appServicePlan.id

@description('Storage Account ID')
output storageAccountId string = storageAccount.id

@description('Storage Account Name')
output storageAccountName string = storageAccount.name

@description('Container Registry ID')
output containerRegistryId string = containerRegistry.id

@description('Container Registry Name')
output containerRegistryName string = containerRegistry.name

@description('Container Registry Login Server')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('Function App Default Hostname')
output functionAppDefaultHostname string = functionApp.properties.defaultHostName

@description('Function App Principal ID')
output functionAppPrincipalId string = functionApp.identity.principalId
