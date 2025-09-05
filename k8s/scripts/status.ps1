# Check n8n deployment status in Minikube - PowerShell Version
# Author: AI Assistant
# Description: Script to check the status of n8n deployment (Windows)

param(
    [switch]$Help,
    [switch]$Detailed
)

# Set error action preference
$ErrorActionPreference = "Continue"

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
n8n Status Checker for Windows

Usage: .\status.ps1 [OPTIONS]

Options:
  -Help        Show this help message
  -Detailed    Show detailed information including events and logs

Description:
  This script checks the current status of n8n deployment in Minikube:
  1. Verifies Minikube is running
  2. Checks namespace existence
  3. Shows deployment, pod, and service status
  4. Provides access information
  5. Shows recent events (if -Detailed)

Examples:
  .\status.ps1
  .\status.ps1 -Detailed

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

# Function to get pod status
function Get-PodStatus {
    try {
        $status = kubectl get pods -n $NAMESPACE -l app=n8n -o jsonpath='{.items[0].status.phase}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $status) {
            return $status
        }
        else {
            return "NotFound"
        }
    }
    catch {
        return "NotFound"
    }
}

# Function to check service accessibility
function Test-ServiceAccess {
    Write-Status "Checking service accessibility..."
    
    # Get Minikube IP
    try {
        $minikubeIP = minikube ip 2>$null
        if ($LASTEXITCODE -ne 0) {
            $minikubeIP = "unknown"
        }
    }
    catch {
        $minikubeIP = "unknown"
    }
    
    Write-Host ""
    Write-Host "=== Access Methods ===" -ForegroundColor Cyan
    Write-Host "1. Port Forward (recommended for development):" -ForegroundColor White
    Write-Host "   kubectl port-forward service/n8n-service 5678:5678 -n $NAMESPACE" -ForegroundColor Gray
    Write-Host "   Then open: http://localhost:5678" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. NodePort Service:" -ForegroundColor White
    Write-Host "   minikube service n8n-nodeport -n $NAMESPACE" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Direct NodePort URL:" -ForegroundColor White
    Write-Host "   http://${minikubeIP}:30678" -ForegroundColor Gray
    Write-Host ""
    
    # Test if service is responding
    try {
        $podName = kubectl get pods -n $NAMESPACE -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $podName) {
            Write-Status "Testing service health..."
            $healthCheck = kubectl exec -n $NAMESPACE $podName -- wget -q --spider http://localhost:5678/healthz 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Service is healthy and responding"
            }
            else {
                Write-Warning "Service may not be fully ready yet"
            }
        }
    }
    catch {
        Write-Warning "Could not test service health"
    }
}

# Main status check function
function Get-Status {
    Write-Status "Checking n8n deployment status in Minikube..."
    Write-Host "Platform: Windows PowerShell" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if Minikube is running
    try {
        minikube status 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Minikube is not running. Please start it with: minikube start"
            return $false
        }
    }
    catch {
        Write-Error "Minikube is not running. Please start it with: minikube start"
        return $false
    }
    
    Write-Success "Minikube is running"
    
    # Check if namespace exists
    if (-not (Test-NamespaceExists $NAMESPACE)) {
        Write-Error "Namespace '$NAMESPACE' does not exist. n8n is not deployed."
        Write-Host "To deploy n8n, run: .\scripts\build-and-deploy.ps1" -ForegroundColor Yellow
        return $false
    }
    
    Write-Success "Namespace '$NAMESPACE' exists"
    
    Write-Host ""
    Write-Host "=== Deployment Status ===" -ForegroundColor Cyan
    kubectl get deployments -n $NAMESPACE
    
    Write-Host ""
    Write-Host "=== Pod Status ===" -ForegroundColor Cyan
    kubectl get pods -n $NAMESPACE -o wide
    
    Write-Host ""
    Write-Host "=== Service Status ===" -ForegroundColor Cyan
    kubectl get services -n $NAMESPACE
    
    Write-Host ""
    Write-Host "=== ConfigMap and Secrets ===" -ForegroundColor Cyan
    kubectl get configmaps,secrets -n $NAMESPACE
    
    Write-Host ""
    Write-Host "=== Persistent Volumes ===" -ForegroundColor Cyan
    kubectl get pv,pvc -n $NAMESPACE
    
    # Check pod status
    $podStatus = Get-PodStatus
    Write-Host ""
    Write-Host "=== Pod Health ===" -ForegroundColor Cyan
    switch ($podStatus) {
        "Running" {
            Write-Success "Pod is running"
        }
        "Pending" {
            Write-Warning "Pod is pending (may be starting up)"
        }
        "Failed" {
            Write-Error "Pod has failed"
        }
        "Error" {
            Write-Error "Pod has error"
        }
        "NotFound" {
            Write-Error "No n8n pods found"
        }
        default {
            Write-Warning "Pod status: $podStatus"
        }
    }
    
    # Show recent events
    if ($Detailed) {
        Write-Host ""
        Write-Host "=== Recent Events ===" -ForegroundColor Cyan
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | Select-Object -Last 10
        
        # Show pod logs if pod is running
        if ($podStatus -eq "Running") {
            Write-Host ""
            Write-Host "=== Recent Logs (last 20 lines) ===" -ForegroundColor Cyan
            try {
                $podName = kubectl get pods -n $NAMESPACE -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>$null
                if ($podName) {
                    kubectl logs $podName -n $NAMESPACE --tail=20
                }
            }
            catch {
                Write-Warning "Could not retrieve logs"
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "=== Recent Events (last 5) ===" -ForegroundColor Cyan
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | Select-Object -Last 5
    }
    
    # Check service accessibility
    if ($podStatus -eq "Running") {
        Test-ServiceAccess
    }
    
    Write-Host ""
    Write-Host "=== Default Credentials ===" -ForegroundColor Cyan
    Write-Host "Username: admin" -ForegroundColor White
    Write-Host "Password: password123" -ForegroundColor White
    Write-Host ""
    
    Write-Host "=== PowerShell Management Commands ===" -ForegroundColor Cyan
    Write-Host "View logs:       .\scripts\logs.ps1" -ForegroundColor Gray
    Write-Host "Follow logs:     .\scripts\logs.ps1 -Follow" -ForegroundColor Gray
    Write-Host "Cleanup:         .\scripts\cleanup.ps1" -ForegroundColor Gray
    Write-Host "Redeploy:        .\scripts\build-and-deploy.ps1" -ForegroundColor Gray
    Write-Host ""
    
    Write-Status "Status check completed."
    return $true
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    try {
        $success = Get-Status
        if (-not $success) {
            exit 1
        }
    }
    catch {
        Write-Error "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main
