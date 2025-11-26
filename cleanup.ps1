# Azure Landing Zone Cleanup Script
# This script helps clean up the landing zone infrastructure

param(
    [switch]$Force,
    [switch]$WhatIf
)

Write-Host "🧹 Azure Landing Zone Cleanup" -ForegroundColor Red
Write-Host "==============================" -ForegroundColor Red

# Check if azd is installed
if (!(Get-Command "azd" -ErrorAction SilentlyContinue)) {
    Write-Error "Azure Developer CLI (azd) is not installed. Please install it from: https://aka.ms/azure-dev/install"
    exit 1
}

# Show what would be deleted
if ($WhatIf) {
    Write-Host "🔍 What-If Mode: Showing what would be deleted..." -ForegroundColor Yellow
    azd show
    exit 0
}

# Warning message
Write-Host "⚠️  WARNING: This will delete ALL resources created by this landing zone!" -ForegroundColor Red
Write-Host "⚠️  This action cannot be undone!" -ForegroundColor Red
Write-Host ""

# Show current resources
Write-Host "📋 Current environment:" -ForegroundColor Cyan
azd show

Write-Host ""

if (!$Force) {
    # Double confirmation for safety
    $confirmation = Read-Host "Are you absolutely sure you want to delete all resources? Type 'DELETE' to confirm"
    if ($confirmation -ne 'DELETE') {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
        exit 0
    }
    
    $finalConfirmation = Read-Host "Last chance! Type 'YES' to permanently delete all resources"
    if ($finalConfirmation -ne 'YES') {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Clean up resources
Write-Host "🗑️ Deleting resources..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray

try {
    azd down --force --purge
    
    Write-Host ""
    Write-Host "✅ Cleanup completed successfully!" -ForegroundColor Green
    Write-Host "All resources have been deleted." -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Cleanup failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 You may need to manually delete remaining resources from Azure Portal" -ForegroundColor Yellow
    exit 1
}