targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Primary location for all resources')
param location string

@minLength(1)
@maxLength(64) 
@description('Name of the project/workload (used as prefix for resource names)')
param projectName string

@description('Environment name (e.g., dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Principal ID of the user who will be granted permissions')
param principalId string = ''

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('Tags to apply to all resources')
param tags object = {}

// Load abbreviations
var resourceToken = toLower(uniqueString(subscription().id, projectName, location))
var commonTags = union(tags, {
  'azd-env-name': environmentName
  project: projectName
  environment: environmentName
  'deployed-by': 'azd'
})

// Define resource group names (shortened to fit length limits)
var resourceGroups = {
  security: 'rg-${projectName}-sec-${environmentName}-${take(resourceToken, 6)}'
  monitoring: 'rg-${projectName}-mon-${environmentName}-${take(resourceToken, 6)}'
  app1: 'rg-${projectName}-app1-${environmentName}-${take(resourceToken, 6)}'
  app2: 'rg-${projectName}-app2-${environmentName}-${take(resourceToken, 6)}'
  database: 'rg-${projectName}-db-${environmentName}-${take(resourceToken, 6)}'
  shared: 'rg-${projectName}-shr-${environmentName}-${take(resourceToken, 6)}'
}

// Security Resource Group
resource rgSecurity 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.security
  location: location
  tags: union(commonTags, {
    purpose: 'security'
    description: 'Security services including Key Vault, security policies, and compliance'
  })
}

// Monitoring Resource Group  
resource rgMonitoring 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.monitoring
  location: location
  tags: union(commonTags, {
    purpose: 'monitoring'
    description: 'Monitoring services including Log Analytics, Application Insights, and alerts'
  })
}

// App1 Resource Group
resource rgApp1 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.app1
  location: location
  tags: union(commonTags, {
    purpose: 'application'
    application: 'app1'
    description: 'Application 1 resources including compute, storage, and networking'
  })
}

// App2 Resource Group
resource rgApp2 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.app2
  location: location
  tags: union(commonTags, {
    purpose: 'application' 
    application: 'app2'
    description: 'Application 2 resources including compute, storage, and networking'
  })
}

// Database Resource Group
resource rgDatabase 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.database
  location: location
  tags: union(commonTags, {
    purpose: 'database'
    description: 'Database services including SQL, Cosmos DB, and backup storage'
  })
}

// Shared Services Resource Group
resource rgShared 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroups.shared
  location: location
  tags: union(commonTags, {
    purpose: 'shared-services'
    description: 'Shared services including networking, DNS, and common utilities'
  })
}

// Deploy shared services
module sharedServices 'modules/shared-services.bicep' = {
  scope: rgShared
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
  }
}

// Deploy security services
module securityServices 'modules/security.bicep' = {
  scope: rgSecurity
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
    principalId: principalId
    logAnalyticsWorkspaceId: monitoringServices.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy monitoring services  
module monitoringServices 'modules/monitoring.bicep' = {
  scope: rgMonitoring
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
  }
}

// Deploy database services
module databaseServices 'modules/database.bicep' = {
  scope: rgDatabase
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
    subnetId: sharedServices.outputs.databaseSubnetId
    keyVaultId: securityServices.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoringServices.outputs.logAnalyticsWorkspaceId
    sqlAdminPassword: sqlAdminPassword
  }
}

// Deploy app1 services
module app1Services 'modules/app1.bicep' = {
  scope: rgApp1
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
    subnetId: sharedServices.outputs.app1SubnetId
    keyVaultId: securityServices.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoringServices.outputs.logAnalyticsWorkspaceId
    applicationInsightsId: monitoringServices.outputs.applicationInsightsId
  }
}

// Deploy app2 services
module app2Services 'modules/app2.bicep' = {
  scope: rgApp2
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: commonTags
    resourceToken: resourceToken
    subnetId: sharedServices.outputs.app2SubnetId
    keyVaultId: securityServices.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoringServices.outputs.logAnalyticsWorkspaceId
    applicationInsightsId: monitoringServices.outputs.applicationInsightsId
  }
}

// Outputs for environment variables
@description('Security Resource Group name')
output AZURE_RESOURCE_GROUP_SECURITY string = resourceGroups.security

@description('Monitoring Resource Group name')
output AZURE_RESOURCE_GROUP_MONITORING string = resourceGroups.monitoring

@description('App1 Resource Group name')
output AZURE_RESOURCE_GROUP_APP1 string = resourceGroups.app1

@description('App2 Resource Group name')
output AZURE_RESOURCE_GROUP_APP2 string = resourceGroups.app2

@description('Database Resource Group name')
output AZURE_RESOURCE_GROUP_DATABASE string = resourceGroups.database

@description('Shared Services Resource Group name') 
output AZURE_RESOURCE_GROUP_SHARED string = resourceGroups.shared

@description('Key Vault ID for secure string storage')
output AZURE_KEY_VAULT_ID string = securityServices.outputs.keyVaultId

@description('Log Analytics Workspace ID')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoringServices.outputs.logAnalyticsWorkspaceId

@description('Application Insights ID')
output AZURE_APPLICATION_INSIGHTS_ID string = monitoringServices.outputs.applicationInsightsId

@description('Virtual Network ID')
output AZURE_VIRTUAL_NETWORK_ID string = sharedServices.outputs.virtualNetworkId
