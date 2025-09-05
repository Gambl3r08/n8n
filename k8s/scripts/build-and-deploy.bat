@echo off
REM Build and Deploy n8n to Minikube - Batch Version
REM Author: AI Assistant
REM Description: Complete automation script for n8n deployment in Minikube (Windows CMD)

setlocal EnableDelayedExpansion

REM Configuration
set NAMESPACE=n8n
set IMAGE_NAME=n8n-local
set IMAGE_TAG=latest

REM Color definitions (if supported)
set COLOR_INFO=36
set COLOR_SUCCESS=32
set COLOR_WARNING=33
set COLOR_ERROR=31

REM Function to print colored messages
:print_status
echo [INFO] %~1
goto :eof

:print_success
echo [SUCCESS] %~1
goto :eof

:print_warning
echo [WARNING] %~1
goto :eof

:print_error
echo [ERROR] %~1
goto :eof

REM Check if help is requested
if "%1"=="--help" goto show_help
if "%1"=="-h" goto show_help
if "%1"=="/?" goto show_help

REM Main execution
call :print_status "Starting n8n deployment to Minikube..."
echo Platform: Windows Command Prompt

REM Check prerequisites
call :print_status "Checking prerequisites..."

where docker >nul 2>&1
if errorlevel 1 (
    call :print_error "Docker is not installed or not in PATH"
    echo Please install Docker Desktop: https://www.docker.com/products/docker-desktop/
    exit /b 1
)

where minikube >nul 2>&1
if errorlevel 1 (
    call :print_error "Minikube is not installed or not in PATH"
    echo Please install Minikube: https://minikube.sigs.k8s.io/docs/start/
    exit /b 1
)

where kubectl >nul 2>&1
if errorlevel 1 (
    call :print_error "kubectl is not installed or not in PATH"
    echo Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
    exit /b 1
)

call :print_success "All prerequisites are installed."

REM Start Minikube if not running
call :print_status "Checking Minikube status..."
minikube status >nul 2>&1
if errorlevel 1 (
    call :print_status "Starting Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
    if errorlevel 1 (
        call :print_error "Failed to start Minikube"
        exit /b 1
    )
    call :print_success "Minikube started successfully."
) else (
    call :print_success "Minikube is already running."
)

REM Configure Docker environment
call :print_status "Configuring Docker environment for Minikube..."
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd') do %%i
if errorlevel 1 (
    call :print_error "Failed to configure Docker environment"
    exit /b 1
)
call :print_success "Docker environment configured."

REM Build Docker image
call :print_status "Building n8n Docker image..."
cd /d "%~dp0..\.."
docker build -t %IMAGE_NAME%:%IMAGE_TAG% -f k8s/Dockerfile .
if errorlevel 1 (
    call :print_error "Failed to build Docker image"
    exit /b 1
)
call :print_success "Docker image built successfully: %IMAGE_NAME%:%IMAGE_TAG%"

REM Apply Kubernetes manifests
call :print_status "Applying Kubernetes manifests..."
cd /d "%~dp0.."

kubectl apply -f namespace.yaml
if errorlevel 1 goto manifest_error

kubectl apply -f configmap.yaml
if errorlevel 1 goto manifest_error

kubectl apply -f secret.yaml
if errorlevel 1 goto manifest_error

kubectl apply -f persistent-volume.yaml
if errorlevel 1 goto manifest_error

kubectl apply -f deployment.yaml
if errorlevel 1 goto manifest_error

kubectl apply -f service.yaml
if errorlevel 1 goto manifest_error

call :print_success "All manifests applied successfully."

REM Wait for deployment to be ready
call :print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/n8n-deployment -n %NAMESPACE%
if errorlevel 1 (
    call :print_error "Deployment failed to become ready"
    exit /b 1
)
call :print_success "Deployment is ready."

REM Show service information
call :print_status "Getting service information..."
echo.
echo === n8n Service Information ===
kubectl get services -n %NAMESPACE%

echo.
echo === Pod Status ===
kubectl get pods -n %NAMESPACE%

echo.
echo === Access URLs ===
echo 1. Using kubectl port-forward:
echo    kubectl port-forward service/n8n-service 5678:5678 -n %NAMESPACE%
echo    Then open: http://localhost:5678
echo.
echo 2. Using minikube service:
echo    minikube service n8n-nodeport -n %NAMESPACE%
echo.
echo 3. Direct NodePort access:
for /f "tokens=*" %%i in ('minikube ip 2^>nul') do set MINIKUBE_IP=%%i
if defined MINIKUBE_IP (
    echo    http://%MINIKUBE_IP%:30678
) else (
    echo    http://^<minikube-ip^>:30678
)
echo.
echo === Default Credentials ===
echo Username: admin
echo Password: password123
echo.
echo === Batch Commands ===
echo Status:      scripts\status.bat
echo Logs:        scripts\logs.bat
echo Cleanup:     scripts\cleanup.bat

call :print_success "n8n has been successfully deployed to Minikube!"
call :print_warning "Note: This is a development setup. For production, configure proper secrets and persistent storage."
goto :eof

:manifest_error
call :print_error "Failed to apply Kubernetes manifests"
exit /b 1

:show_help
echo n8n Minikube Deployment Script for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   --help, -h, /?   Show this help message
echo.
echo Description:
echo   This script performs a complete deployment of n8n to Minikube:
echo   1. Checks prerequisites (Docker, Minikube, kubectl)
echo   2. Starts Minikube if not running
echo   3. Configures Docker environment
echo   4. Builds n8n Docker image
echo   5. Applies Kubernetes manifests
echo   6. Waits for deployment to be ready
echo   7. Shows access information
echo.
echo Examples:
echo   %~nx0
echo.
goto :eof
