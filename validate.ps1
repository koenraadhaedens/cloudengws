# Landing Zone Validation Script
# This script validates the project structure and configuration

Write-Host "🔍 Azure Landing Zone Validation" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

$errors = @()
$warnings = @()

# Check required files
$requiredFiles = @(
    "azure.yaml",
    "infra/main.bicep", 
    "infra/main.bicepparam",
    "infra/abbreviations.json",
    "infra/modules/shared-services.bicep",
    "infra/modules/security.bicep", 
    "infra/modules/monitoring.bicep",
    "infra/modules/database.bicep",
    "infra/modules/app1.bicep",
    "infra/modules/app2.bicep",
    "README.md",
    ".gitignore"
)

Write-Host "📁 Checking project structure..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file" -ForegroundColor Red
        $errors += "Missing file: $file"
    }
}

# Check required tools
Write-Host ""
Write-Host "🛠️ Checking required tools..." -ForegroundColor Yellow

$tools = @(
    @{ Name = "azd"; Command = "azd"; Description = "Azure Developer CLI" },
    @{ Name = "az"; Command = "az"; Description = "Azure CLI" },
    @{ Name = "pwsh"; Command = "pwsh"; Description = "PowerShell" }
)

foreach ($tool in $tools) {
    if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
        $version = & $tool.Command --version 2>$null
        Write-Host "  ✅ $($tool.Description): $($version[0])" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($tool.Description)" -ForegroundColor Red
        $errors += "Missing tool: $($tool.Description)"
    }
}

# Check environment variables
Write-Host ""
Write-Host "⚙️ Checking environment configuration..." -ForegroundColor Yellow

$envVars = @(
    @{ Name = "AZURE_SUBSCRIPTION_ID"; Required = $false; Description = "Azure Subscription ID" },
    @{ Name = "AZURE_PRINCIPAL_ID"; Required = $false; Description = "User Principal ID" },
    @{ Name = "SQL_ADMIN_PASSWORD"; Required = $false; Description = "SQL Admin Password" }
)

foreach ($envVar in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($envVar.Name)
    if ($value) {
        if ($envVar.Name -like "*PASSWORD*") {
            Write-Host "  ✅ $($envVar.Name): [REDACTED]" -ForegroundColor Green
        } else {
            Write-Host "  ✅ $($envVar.Name): $value" -ForegroundColor Green
        }
    } elseif ($envVar.Required) {
        Write-Host "  ❌ $($envVar.Name)" -ForegroundColor Red
        $errors += "Missing required environment variable: $($envVar.Name)"
    } else {
        Write-Host "  ⚠️ $($envVar.Name): Not set (will be prompted during deployment)" -ForegroundColor Yellow
        $warnings += "Optional environment variable not set: $($envVar.Name)"
    }
}

# Check Bicep syntax
Write-Host ""
Write-Host "🔧 Validating Bicep templates..." -ForegroundColor Yellow

if (Get-Command "az" -ErrorAction SilentlyContinue) {
    try {
        $bicepValidation = az bicep build --file "infra/main.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Bicep templates are valid" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Bicep validation failed" -ForegroundColor Red
            $errors += "Bicep validation failed"
        }
    } catch {
        Write-Host "  ⚠️ Could not validate Bicep templates (az bicep not available)" -ForegroundColor Yellow
        $warnings += "Bicep validation skipped"
    }
} else {
    Write-Host "  ⚠️ Azure CLI not found - skipping Bicep validation" -ForegroundColor Yellow
    $warnings += "Azure CLI not available for Bicep validation"
}

# Summary
Write-Host ""
Write-Host "📋 Validation Summary" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

if ($errors.Count -eq 0) {
    Write-Host "✅ No critical errors found!" -ForegroundColor Green
} else {
    Write-Host "❌ $($errors.Count) error(s) found:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠️ $($warnings.Count) warning(s):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "🚀 Ready for deployment! Run './deploy.ps1' to deploy the landing zone." -ForegroundColor Green
} else {
    Write-Host "🔧 Please fix the errors above before deployment." -ForegroundColor Red
}

# Exit with error code if validation failed
if ($errors.Count -gt 0) {
    exit 1
}