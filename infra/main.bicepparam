using 'main.bicep'

param location = 'East US'
param projectName = 'cloudengws'
param environmentName = 'dev'
param principalId = '${readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')}'
param sqlAdminPassword = '${readEnvironmentVariable('SQL_ADMIN_PASSWORD', 'P@ssw0rd123!')}'
param tags = {
  'cost-center': 'it-department'
  owner: 'platform-team'
}
