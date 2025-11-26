# Azure Landing Zone Deployment Script
# This script helps deploy the landing zone infrastructure using Azure Developer CLI

param(
    [string]$EnvironmentName = "dev",
    [string]$Location = "eastus",
    [string]$ProjectName = "cloudengws",
    [switch]$SkipLogin,
    [switch]$WhatIf
)

Write-Host "🚀 Azure Landing Zone Deployment" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Check if azd is installed
if (!(Get-Command "azd" -ErrorAction SilentlyContinue)) {
    Write-Error "Azure Developer CLI (azd) is not installed. Please install it from: https://aka.ms/azure-dev/install"
    exit 1
}

# Check if az is installed
if (!(Get-Command "az" -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Login to Azure if not skipped
if (!$SkipLogin) {
    Write-Host "🔐 Logging into Azure..." -ForegroundColor Yellow
    az login --only-show-errors
    azd auth login --only-show-errors
}

# Get current user's object ID for Key Vault access
Write-Host "👤 Getting current user information..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query objectId -o tsv
if (!$currentUser) {
    Write-Error "Unable to get current user information. Please ensure you're logged in to Azure."
    exit 1
}

# Set environment variables
Write-Host "⚙️ Setting environment variables..." -ForegroundColor Yellow
$env:AZURE_ENV_NAME = $EnvironmentName
$env:AZURE_LOCATION = $Location
$env:PROJECT_NAME = $ProjectName
$env:AZURE_PRINCIPAL_ID = $currentUser

# Prompt for SQL Admin Password if not set
if (!$env:SQL_ADMIN_PASSWORD) {
    $securePassword = Read-Host "Enter SQL Server admin password" -AsSecureString
    $env:SQL_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
}

# Validate password strength
if ($env:SQL_ADMIN_PASSWORD.Length -lt 8) {
    Write-Error "SQL Admin password must be at least 8 characters long"
    exit 1
}

Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentName" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White  
Write-Host "  Project: $ProjectName" -ForegroundColor White
Write-Host "  Principal ID: $currentUser" -ForegroundColor White
Write-Host ""

if ($WhatIf) {
    Write-Host "🔍 What-If Mode: Showing what would be deployed..." -ForegroundColor Yellow
    azd provision --preview
    exit 0
}

# Confirm deployment
$confirmation = Read-Host "Do you want to proceed with the deployment? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Red
    exit 0
}

# Deploy infrastructure
Write-Host "🏗️ Deploying infrastructure..." -ForegroundColor Yellow
Write-Host "This may take 15-20 minutes..." -ForegroundColor Gray

try {
    azd up --no-prompt
    
    Write-Host ""
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 View your resources:" -ForegroundColor Cyan
    Write-Host "  Azure Portal: https://portal.azure.com" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review the deployed resources in Azure Portal" -ForegroundColor White
    Write-Host "  2. Configure additional security policies as needed" -ForegroundColor White
    Write-Host "  3. Deploy your applications to the App Service and Function App" -ForegroundColor White
    Write-Host "  4. Set up monitoring alerts and dashboards" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Check your Azure subscription permissions" -ForegroundColor White
    Write-Host "  2. Verify all required environment variables are set" -ForegroundColor White  
    Write-Host "  3. Run 'azd show' to view detailed error logs" -ForegroundColor White
    Write-Host "  4. Try running 'azd provision' for infrastructure-only deployment" -ForegroundColor White
    exit 1
}