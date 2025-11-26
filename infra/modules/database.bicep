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

@description('Database subnet ID for network restrictions')
param subnetId string

@description('Key Vault ID for storing connection strings')
param keyVaultId string

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${abbrs.sqlServer}-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: '${abbrs.sqlDatabase}-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: environmentName == 'prod' ? 'S2' : 'S0'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environmentName == 'prod' ? 268435456000 : 2147483648 // 250GB for prod, 2GB for dev/test
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: environmentName == 'prod'
    readScale: environmentName == 'prod' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: environmentName == 'prod' ? 'Geo' : 'Local'
  }
}

// SQL Server Virtual Network Rule
resource sqlServerVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'allow-database-subnet'
  properties: {
    virtualNetworkSubnetId: subnetId
  }
}

// SQL Server Firewall Rule (Allow Azure Services)
resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Diagnostic settings for SQL Database
resource sqlDatabaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDatabase
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

// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: '${abbrs.cosmosDBAccount}-${projectName}-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: environmentName == 'prod'
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: environmentName == 'prod'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: environmentName == 'prod' ? 240 : 1440
        backupRetentionIntervalInHours: environmentName == 'prod' ? 720 : 168
        backupStorageRedundancy: environmentName == 'prod' ? 'Geo' : 'Local'
      }
    }
  }
}

// Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: 'app-database'
  properties: {
    resource: {
      id: 'app-database'
    }
  }
}

// Cosmos DB Container
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'app-container'
  properties: {
    resource: {
      id: 'app-container'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}

// Diagnostic settings for Cosmos DB
resource cosmosDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cosmosAccount
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

// Store connection strings in Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: last(split(keyVaultId, '/'))
}

resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: keyVault
  name: 'sql-connection-string'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    attributes: {
      enabled: true
    }
  }
}

resource cosmosConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: keyVault
  name: 'cosmos-connection-string'
  properties: {
    value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
    attributes: {
      enabled: true
    }
  }
}

// Outputs
@description('SQL Server ID')
output sqlServerId string = sqlServer.id

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Database ID')
output sqlDatabaseId string = sqlDatabase.id

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name

@description('Cosmos DB Account ID')
output cosmosAccountId string = cosmosAccount.id

@description('Cosmos DB Account Name')
output cosmosAccountName string = cosmosAccount.name

@description('Cosmos DB Database Name')
output cosmosDatabaseName string = cosmosDatabase.name

@description('Cosmos DB Container Name')
output cosmosContainerName string = cosmosContainer.name
