# Landing Zone Infrastructure

This repository contains Infrastructure as Code (IaC) for creating a comprehensive Azure landing zone using Azure Developer CLI (azd).

## Architecture Overview

The landing zone creates the following resource groups and services:

### Resource Groups
- **Security** (`rg-*-sec-*`): Security services including Key Vault, security policies, and compliance
- **Monitoring** (`rg-*-mon-*`): Monitoring services including Log Analytics, Application Insights, and alerts  
- **App1** (`rg-*-app1-*`): Application 1 resources including App Service, storage, and networking
- **App2** (`rg-*-app2-*`): Application 2 resources including Function App, Container Registry, and storage
- **Database** (`rg-*-db-*`): Database services including SQL Server, Cosmos DB, and backup storage
- **Shared Services** (`rg-*-shr-*`): Shared services including VNet, DNS, and common utilities

### Key Services Deployed

#### Security (Security Resource Group)
- Azure Key Vault for secrets management
- Managed Identity for secure authentication
- Access policies and RBAC configurations

#### Monitoring (Monitoring Resource Group)  
- Log Analytics Workspace for centralized logging
- Application Insights for application monitoring
- Action Groups and alert rules
- Data Collection Rules for VM insights

#### Shared Services (Shared Resource Group)
- Virtual Network with multiple subnets
- Network Security Groups with appropriate rules
- Service endpoints for database connectivity

#### Database (Database Resource Group)
- Azure SQL Server and Database
- Cosmos DB with containers
- Network restrictions and firewall rules
- Connection strings stored in Key Vault

#### App1 (App1 Resource Group)
- App Service with .NET 8 runtime
- App Service Plan (Basic/Premium based on environment)
- Storage Account for application data
- VNet integration and Key Vault access

#### App2 (App2 Resource Group)
- Azure Function App with .NET isolated runtime
- Container Registry for containerized workloads
- Storage Account for function runtime
- VNet integration and multi-database connectivity

## Prerequisites

1. **Azure Developer CLI (azd)** - [Install azd](https://docs.microsoft.com/azure/developer/azure-developer-cli/install-azd)
2. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
3. **PowerShell 7+** (Windows) or Bash (Linux/macOS)
4. **Azure subscription** with appropriate permissions

## Quick Start

1. **Clone and initialize the project:**
   ```powershell
   azd init --template .
   ```

2. **Set required environment variables:**
   ```powershell
   # Set your Azure subscription and principal ID
   $env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"
   $env:AZURE_PRINCIPAL_ID = "your-object-id"
   $env:SQL_ADMIN_PASSWORD = "your-secure-password"
   ```

3. **Deploy the infrastructure:**
   ```powershell
   azd up
   ```

## Environment Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_PRINCIPAL_ID` | Your Azure AD user/service principal object ID | `87654321-4321-4321-4321-210987654321` |
| `SQL_ADMIN_PASSWORD` | Strong password for SQL Server admin | `MySecureP@ssw0rd123!` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AZURE_LOCATION` | Azure region for deployment | `eastus` |
| `AZURE_ENV_NAME` | Environment name (dev/test/prod) | `dev` |
| `PROJECT_NAME` | Project name used in resource naming | `cloudengws` |

## Deployment Commands

### Deploy Everything
```powershell
azd up
```

### Deploy Infrastructure Only
```powershell
azd provision
```

### Update Infrastructure
```powershell
azd provision
```

### Clean Up Resources
```powershell
azd down
```

## Project Structure

```
├── azure.yaml                 # azd configuration
├── infra/
│   ├── main.bicep             # Main infrastructure template
│   ├── main.bicepparam        # Parameters file
│   ├── abbreviations.json     # Azure resource abbreviations
│   └── modules/
│       ├── shared-services.bicep  # Networking and shared resources
│       ├── security.bicep          # Key Vault and security services
│       ├── monitoring.bicep        # Log Analytics and monitoring
│       ├── database.bicep          # SQL Server and Cosmos DB
│       ├── app1.bicep             # App Service and related resources
│       └── app2.bicep             # Function App and containers
├── .env                       # Environment variables template
└── README.md                  # This file
```

## Security Features

- **Key Vault Integration**: All sensitive configuration stored securely
- **Managed Identity**: Applications use managed identities for authentication
- **Network Security**: NSGs and VNet integration for network isolation
- **HTTPS Only**: All web applications enforce HTTPS
- **Minimal Permissions**: Least privilege access principles applied

## Monitoring and Observability

- **Centralized Logging**: All services send logs to Log Analytics
- **Application Insights**: Application performance monitoring
- **Diagnostic Settings**: Comprehensive diagnostic data collection
- **Alert Rules**: Proactive monitoring with configurable alerts

## Customization

### Modifying Resource Names
Edit the `abbreviations.json` file to change resource naming conventions.

### Adding New Services
1. Create a new Bicep module in `infra/modules/`
2. Add the module reference to `main.bicep`
3. Update `main.bicepparam` with any new parameters

### Environment-Specific Configuration
The template supports different configurations for dev, test, and prod environments:
- SKU sizes automatically scale based on environment
- Backup and redundancy settings adjust for production workloads
- Security settings become more restrictive in production

## Troubleshooting

### Common Issues

1. **Resource name conflicts**: Resource names include a unique suffix to prevent conflicts
2. **Permission errors**: Ensure your Azure account has Contributor access to the subscription
3. **Parameter validation**: Check that all required environment variables are set

### Getting Help
- View deployment logs: `azd show`
- Check Azure portal for resource status
- Review Bicep linting errors before deployment

## Contributing

1. Make changes to Bicep templates
2. Test with `azd provision` in a dev environment
3. Update documentation if needed
4. Submit pull request

## Cost Optimization

- **Development environments** use Basic/Standard tiers
- **Production environments** use Premium tiers with redundancy
- **Auto-scaling** configured where supported
- **Storage tiers** optimized for access patterns

## Compliance and Governance

- All resources tagged for cost tracking
- Network security groups follow defense-in-depth principles
- Audit logging enabled on all supported services
- Key Vault access logged and monitored