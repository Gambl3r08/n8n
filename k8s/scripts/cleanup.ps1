# Cleanup n8n deployment from Minikube - PowerShell Version
# Author: AI Assistant
# Description: Script to remove all n8n resources from Minikube (Windows)

param(
    [switch]$Help,
    [switch]$Force,
    [switch]$KeepImage
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions for PowerShell
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Configuration
$NAMESPACE = "n8n"

# Function to show help
function Show-Help {
    Write-Host @"
n8n Minikube Cleanup Script for Windows

Usage: .\cleanup.ps1 [OPTIONS]

Options:
  -Help        Show this help message
  -Force       Skip confirmation prompts
  -KeepImage   Don't remove the Docker image

Description:
  This script removes all n8n resources from Minikube:
  1. Deletes Kubernetes resources (services, deployment, etc.)
  2. Removes namespace
  3. Optionally removes Docker image

Examples:
  .\cleanup.ps1
  .\cleanup.ps1 -Force
  .\cleanup.ps1 -KeepImage

"@
}

# Function to check if namespace exists
function Test-NamespaceExists {
    param([string]$NamespaceName)
    try {
        kubectl get namespace $NamespaceName 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Function to get user confirmation
function Get-UserConfirmation {
    param([string]$Message)
    if ($Force) {
        return $true
    }
    
    $response = Read-Host "$Message (y/N)"
    return $response -match "^[Yy]"
}

# Main cleanup function
function Remove-N8nDeployment {
    Write-Status "Starting n8n cleanup from Minikube..."
    Write-Host "Platform: Windows PowerShell" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-NamespaceExists $NAMESPACE)) {
        Write-Warning "Namespace '$NAMESPACE' does not exist. Nothing to cleanup."
        return
    }
    
    if (-not (Get-UserConfirmation "Are you sure you want to delete all n8n resources?")) {
        Write-Status "Cleanup cancelled by user."
        return
    }
    
    Write-Status "Deleting n8n resources..."
    
    # Change to k8s directory
    $k8sDir = Split-Path -Parent $PSScriptRoot
    Push-Location $k8sDir
    
    try {
        # Delete resources in reverse order
        $manifests = @(
            "service.yaml",
            "deployment.yaml",
            "persistent-volume.yaml",
            "secret.yaml",
            "configmap.yaml",
            "namespace.yaml"
        )
        
        foreach ($manifest in $manifests) {
            Write-Status "Deleting resources from $manifest"
            kubectl delete -f $manifest --ignore-not-found=true 2>$null
        }
        
        Write-Success "All n8n resources have been deleted."
        
        # Optional: Remove Docker image
        if (-not $KeepImage) {
            if (Get-UserConfirmation "Do you want to remove the Docker image as well?") {
                Write-Status "Configuring Docker environment..."
                try {
                    $dockerEnv = minikube docker-env --shell powershell | Out-String
                    Invoke-Expression $dockerEnv
                    
                    Write-Status "Removing Docker image..."
                    docker rmi n8n-local:latest --force 2>$null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Docker image removed."
                    }
                    else {
                        Write-Warning "Docker image not found or already removed."
                    }
                }
                catch {
                    Write-Warning "Failed to remove Docker image: $($_.Exception.Message)"
                }
            }
        }
        
        Write-Success "Cleanup completed successfully!"
        Write-Host ""
        Write-Host "To verify cleanup:" -ForegroundColor Cyan
        Write-Host "  kubectl get all -n $NAMESPACE" -ForegroundColor Gray
        Write-Host "  kubectl get namespaces | findstr $NAMESPACE" -ForegroundColor Gray
    }
    catch {
        Write-Error "Cleanup failed: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    try {
        Remove-N8nDeployment
    }
    catch {
        Write-Error "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main
