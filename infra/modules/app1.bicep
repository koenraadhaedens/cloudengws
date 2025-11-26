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

// Storage Account for App1
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${abbrs.storageAccount}${replace(projectName, '-', '')}app1${environmentName}${resourceToken}'
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

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${abbrs.appServicePlan}-app1-${projectName}-${environmentName}-${resourceToken}'
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

// App Service
resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: '${abbrs.appService}-app1-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
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

// Grant App Service access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2024-04-01-preview' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: appService.identity.principalId
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

// Virtual Network Integration
resource vnetIntegration 'Microsoft.Web/sites/networkConfig@2023-12-01' = {
  parent: appService
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: subnetId
    swiftSupported: true
  }
}

// Diagnostic settings for App Service
resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
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

// Outputs
@description('App Service ID')
output appServiceId string = appService.id

@description('App Service Name')
output appServiceName string = appService.name

@description('App Service Plan ID')
output appServicePlanId string = appServicePlan.id

@description('Storage Account ID')
output storageAccountId string = storageAccount.id

@description('Storage Account Name')
output storageAccountName string = storageAccount.name

@description('App Service Default Hostname')
output appServiceDefaultHostname string = appService.properties.defaultHostName

@description('App Service Principal ID')
output appServicePrincipalId string = appService.identity.principalId
