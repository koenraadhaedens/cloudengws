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

@description('Principal ID of the user who will be granted permissions')
param principalId string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: '${abbrs.keyVault}-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: tenant().tenantId
    accessPolicies: principalId != '' ? [
      {
        tenantId: tenant().tenantId
        objectId: principalId
        permissions: {
          keys: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          certificates: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
            'deleteissuers'
            'getissuers'
            'listissuers'
            'managecontacts'
            'manageissuers'
            'setissuers'
          ]
        }
      }
    ] : []
    sku: {
      family: 'A'
      name: environmentName == 'prod' ? 'premium' : 'standard'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
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

// Managed Identity for applications
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${abbrs.managedIdentity}-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
}

// Grant the managed identity access to Key Vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2024-04-01-preview' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: managedIdentity.properties.principalId
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

// Sample secrets for demonstration
resource databaseConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: keyVault
  name: 'database-connection-string'
  properties: {
    value: 'placeholder-connection-string'
    attributes: {
      enabled: true
    }
  }
}

// Outputs
@description('Key Vault ID')
output keyVaultId string = keyVault.id

@description('Key Vault Name')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Managed Identity ID')
output managedIdentityId string = managedIdentity.id

@description('Managed Identity Principal ID')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId

@description('Managed Identity Client ID')
output managedIdentityClientId string = managedIdentity.properties.clientId
