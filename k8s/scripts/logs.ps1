# View n8n logs in Minikube - PowerShell Version
# Author: AI Assistant
# Description: Script to view n8n pod logs with options (Windows)

param(
    [switch]$Follow,
    [int]$Lines = 100,
    [string]$Since = "",
    [switch]$Help
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
n8n Logs Viewer for Windows

Usage: .\logs.ps1 [OPTIONS]

Options:
  -Follow      Follow log output (like tail -f)
  -Lines N     Show last N lines (default: 100)
  -Since       Show logs since timestamp (e.g., 5m, 1h, 2023-01-01T00:00:00Z)
  -Help        Show this help message

Examples:
  .\logs.ps1                    # Show last 100 lines
  .\logs.ps1 -Follow            # Follow logs in real-time
  .\logs.ps1 -Lines 50          # Show last 50 lines
  .\logs.ps1 -Since 10m         # Show logs from last 10 minutes
  .\logs.ps1 -Follow -Since 5m  # Follow logs from last 5 minutes

"@
}

# Function to get pod name
function Get-PodName {
    try {
        $podName = kubectl get pods -n $NAMESPACE -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $podName) {
            return $podName
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

# Main function
function Show-Logs {
    Write-Status "Getting n8n pod logs..."
    Write-Host "Platform: Windows PowerShell" -ForegroundColor Cyan
    Write-Host ""
    
    # Get pod name
    $podName = Get-PodName
    
    if (-not $podName) {
        Write-Error "No n8n pod found in namespace '$NAMESPACE'"
        Write-Status "Available pods:"
        kubectl get pods -n $NAMESPACE
        exit 1
    }
    
    Write-Success "Found pod: $podName"
    
    # Build kubectl logs command
    $kubectlArgs = @("logs", $podName, "-n", $NAMESPACE)
    
    if ($Follow) {
        $kubectlArgs += "-f"
    }
    
    if ($Since) {
        $kubectlArgs += "--since=$Since"
    }
    else {
        $kubectlArgs += "--tail=$Lines"
    }
    
    $command = "kubectl " + ($kubectlArgs -join " ")
    Write-Status "Executing: $command"
    Write-Host ""
    
    try {
        # Execute the command
        & kubectl $kubectlArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "kubectl logs command failed"
        }
    }
    catch {
        Write-Error "Failed to get logs: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Check if the pod is running: kubectl get pods -n $NAMESPACE" -ForegroundColor Gray
        Write-Host "2. Check pod status: kubectl describe pod $podName -n $NAMESPACE" -ForegroundColor Gray
        Write-Host "3. Check deployment status: .\status.ps1" -ForegroundColor Gray
        exit 1
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    # Validate parameters
    if ($Lines -lt 1) {
        Write-Error "Lines parameter must be greater than 0"
        exit 1
    }
    
    if ($Since -and $Since -notmatch "^\d+[smhd]$|^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}") {
        Write-Warning "Since parameter format should be like: 5m, 1h, 2d or 2023-01-01T00:00:00Z"
    }
    
    try {
        Show-Logs
    }
    catch {
        Write-Error "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Handle Ctrl+C gracefully when following logs
if ($Follow) {
    try {
        Main
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host ""
        Write-Status "Log following stopped by user."
        exit 0
    }
}
else {
    Main
}
