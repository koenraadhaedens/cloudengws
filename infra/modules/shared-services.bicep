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

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: '${abbrs.virtualNetwork}-${projectName}-shared-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: '${abbrs.subnet}-app1'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgApp1.id
          }
        }
      }
      {
        name: '${abbrs.subnet}-app2'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: nsgApp2.id
          }
        }
      }
      {
        name: '${abbrs.subnet}-database'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: nsgDatabase.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
      {
        name: '${abbrs.subnet}-shared'
        properties: {
          addressPrefix: '10.0.4.0/24'
          networkSecurityGroup: {
            id: nsgShared.id
          }
        }
      }
    ]
  }
}

// Network Security Groups
resource nsgApp1 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${abbrs.networkSecurityGroup}-app1-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgApp2 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${abbrs.networkSecurityGroup}-app2-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgDatabase 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${abbrs.networkSecurityGroup}-database-${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSQLFromApps'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '1433'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefixes: [
            '10.0.1.0/24'
            '10.0.2.0/24'
          ]
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgShared 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${abbrs.networkSecurityGroup}-shared-${environmentName}-${resourceToken}'
  location: location
  tags: tags
}

// Outputs
@description('Virtual Network ID')
output virtualNetworkId string = virtualNetwork.id

@description('App1 Subnet ID')
output app1SubnetId string = virtualNetwork.properties.subnets[0].id

@description('App2 Subnet ID')
output app2SubnetId string = virtualNetwork.properties.subnets[1].id

@description('Database Subnet ID')
output databaseSubnetId string = virtualNetwork.properties.subnets[2].id

@description('Shared Subnet ID')
output sharedSubnetId string = virtualNetwork.properties.subnets[3].id
