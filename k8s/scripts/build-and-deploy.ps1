# Build and Deploy n8n to Minikube - PowerShell Version
# Author: AI Assistant
# Description: Complete automation script for n8n deployment in Minikube (Windows)

param(
    [switch]$Help,
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

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
$IMAGE_NAME = "n8n-local"
$IMAGE_TAG = "latest"

# Function to show help
function Show-Help {
    Write-Host @"
n8n Minikube Deployment Script for Windows

Usage: .\build-and-deploy.ps1 [OPTIONS]

Options:
  -Help      Show this help message
  -Verbose   Enable verbose output

Description:
  This script performs a complete deployment of n8n to Minikube:
  1. Checks prerequisites (Docker, Minikube, kubectl)
  2. Starts Minikube if not running
  3. Configures Docker environment
  4. Builds n8n Docker image
  5. Applies Kubernetes manifests
  6. Waits for deployment to be ready
  7. Shows access information

Examples:
  .\build-and-deploy.ps1
  .\build-and-deploy.ps1 -Verbose

"@
}

# Function to check if command exists
function Test-Command {
    param([string]$CommandName)
    try {
        Get-Command $CommandName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $missingTools = @()
    
    if (-not (Test-Command "docker")) {
        $missingTools += "Docker"
    }
    
    if (-not (Test-Command "minikube")) {
        $missingTools += "Minikube"
    }
    
    if (-not (Test-Command "kubectl")) {
        $missingTools += "kubectl"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Host "Please install the missing tools and try again." -ForegroundColor Red
        Write-Host "Installation guides:"
        Write-Host "- Docker Desktop: https://www.docker.com/products/docker-desktop/"
        Write-Host "- Minikube: https://minikube.sigs.k8s.io/docs/start/"
        Write-Host "- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        exit 1
    }
    
    Write-Success "All prerequisites are installed."
}

# Start Minikube if not running
function Start-Minikube {
    Write-Status "Checking Minikube status..."
    
    try {
        $status = minikube status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Minikube is already running."
            return
        }
    }
    catch {
        # Minikube not running
    }
    
    Write-Status "Starting Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Minikube started successfully."
    }
    else {
        Write-Error "Failed to start Minikube."
        exit 1
    }
}

# Configure Docker environment
function Set-DockerEnvironment {
    Write-Status "Configuring Docker environment for Minikube..."
    
    try {
        # Get Docker environment variables from Minikube
        $dockerEnv = minikube docker-env --shell powershell | Out-String
        
        # Execute the environment setup
        Invoke-Expression $dockerEnv
        
        Write-Success "Docker environment configured."
    }
    catch {
        Write-Error "Failed to configure Docker environment: $($_.Exception.Message)"
        exit 1
    }
}

# Build Docker image
function Build-DockerImage {
    Write-Status "Building n8n Docker image..."
    
    # Change to project root (assuming script is in k8s/scripts/)
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Push-Location $projectRoot
    
    try {
        # Build the image using the Dockerfile in k8s/
        docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f k8s/Dockerfile .
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        else {
            throw "Docker build failed"
        }
    }
    catch {
        Write-Error "Failed to build Docker image: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Apply Kubernetes manifests
function Deploy-Manifests {
    Write-Status "Applying Kubernetes manifests..."
    
    # Change to k8s directory
    $k8sDir = Split-Path -Parent $PSScriptRoot
    Push-Location $k8sDir
    
    try {
        # Apply manifests in order
        $manifests = @(
            "namespace.yaml",
            "configmap.yaml", 
            "secret.yaml",
            "persistent-volume.yaml",
            "deployment.yaml",
            "service.yaml"
        )
        
        foreach ($manifest in $manifests) {
            Write-Verbose "Applying $manifest"
            kubectl apply -f $manifest
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to apply $manifest"
            }
        }
        
        Write-Success "All manifests applied successfully."
    }
    catch {
        Write-Error "Failed to apply manifests: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Wait for deployment to be ready
function Wait-ForDeployment {
    Write-Status "Waiting for deployment to be ready..."
    
    try {
        kubectl wait --for=condition=available --timeout=300s deployment/n8n-deployment -n $NAMESPACE
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Deployment is ready."
        }
        else {
            throw "Deployment failed to become ready"
        }
    }
    catch {
        Write-Error "Deployment did not become ready in time: $($_.Exception.Message)"
        exit 1
    }
}

# Get service information
function Get-ServiceInfo {
    Write-Status "Getting service information..."
    
    Write-Host ""
    Write-Host "=== n8n Service Information ===" -ForegroundColor Cyan
    kubectl get services -n $NAMESPACE
    
    Write-Host ""
    Write-Host "=== Pod Status ===" -ForegroundColor Cyan
    kubectl get pods -n $NAMESPACE
    
    Write-Host ""
    Write-Host "=== Access URLs ===" -ForegroundColor Cyan
    Write-Host "1. Using kubectl port-forward:" -ForegroundColor White
    Write-Host "   kubectl port-forward service/n8n-service 5678:5678 -n $NAMESPACE" -ForegroundColor Gray
    Write-Host "   Then open: http://localhost:5678" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Using minikube service:" -ForegroundColor White
    Write-Host "   minikube service n8n-nodeport -n $NAMESPACE" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Direct NodePort access:" -ForegroundColor White
    try {
        $minikubeIP = minikube ip
        Write-Host "   http://${minikubeIP}:30678" -ForegroundColor Gray
    }
    catch {
        Write-Host "   http://<minikube-ip>:30678" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "=== Default Credentials ===" -ForegroundColor Cyan
    Write-Host "Username: admin" -ForegroundColor White
    Write-Host "Password: password123" -ForegroundColor White
    Write-Host ""
    Write-Host "=== PowerShell Commands ===" -ForegroundColor Cyan
    Write-Host "Status:      .\scripts\status.ps1" -ForegroundColor Gray
    Write-Host "Logs:        .\scripts\logs.ps1" -ForegroundColor Gray
    Write-Host "Cleanup:     .\scripts\cleanup.ps1" -ForegroundColor Gray
}

# Main execution function
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Status "Starting n8n deployment to Minikube..."
    Write-Host "Platform: Windows PowerShell" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Test-Prerequisites
        Start-Minikube
        Set-DockerEnvironment
        Build-DockerImage
        Deploy-Manifests
        Wait-ForDeployment
        Get-ServiceInfo
        
        Write-Success "n8n has been successfully deployed to Minikube!"
        Write-Warning "Note: This is a development setup. For production, configure proper secrets and persistent storage."
    }
    catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        Write-Host "Run '.\scripts\status.ps1' to check the current state." -ForegroundColor Yellow
        exit 1
    }
}

# Run main function
Main
