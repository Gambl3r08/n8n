@echo off
REM Cleanup n8n deployment from Minikube - Batch Version
REM Author: AI Assistant
REM Description: Script to remove all n8n resources from Minikube (Windows CMD)

setlocal EnableDelayedExpansion

REM Configuration
set NAMESPACE=n8n

REM Function to print messages
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
call :print_status "Starting n8n cleanup from Minikube..."
echo Platform: Windows Command Prompt
echo.

REM Check if namespace exists
kubectl get namespace %NAMESPACE% >nul 2>&1
if errorlevel 1 (
    call :print_warning "Namespace '%NAMESPACE%' does not exist. Nothing to cleanup."
    goto :eof
)

REM Ask for confirmation unless /y is specified
if not "%1"=="/y" (
    set /p "confirm=Are you sure you want to delete all n8n resources? (y/N): "
    if /i not "!confirm!"=="y" (
        call :print_status "Cleanup cancelled by user."
        goto :eof
    )
)

call :print_status "Deleting n8n resources..."

REM Change to k8s directory
cd /d "%~dp0.."

REM Delete resources in reverse order
call :print_status "Deleting services..."
kubectl delete -f service.yaml --ignore-not-found=true >nul 2>&1

call :print_status "Deleting deployment..."
kubectl delete -f deployment.yaml --ignore-not-found=true >nul 2>&1

call :print_status "Deleting persistent volume..."
kubectl delete -f persistent-volume.yaml --ignore-not-found=true >nul 2>&1

call :print_status "Deleting secret..."
kubectl delete -f secret.yaml --ignore-not-found=true >nul 2>&1

call :print_status "Deleting configmap..."
kubectl delete -f configmap.yaml --ignore-not-found=true >nul 2>&1

call :print_status "Deleting namespace..."
kubectl delete -f namespace.yaml --ignore-not-found=true >nul 2>&1

call :print_success "All n8n resources have been deleted."

REM Optional: Remove Docker image
if not "%2"=="--keep-image" (
    set /p "remove_image=Do you want to remove the Docker image as well? (y/N): "
    if /i "!remove_image!"=="y" (
        call :print_status "Configuring Docker environment..."
        for /f "tokens=*" %%i in ('minikube docker-env --shell cmd 2^>nul') do %%i
        
        call :print_status "Removing Docker image..."
        docker rmi n8n-local:latest --force >nul 2>&1
        if errorlevel 1 (
            call :print_warning "Docker image not found or already removed."
        ) else (
            call :print_success "Docker image removed."
        )
    )
)

call :print_success "Cleanup completed successfully!"
echo.
echo To verify cleanup:
echo   kubectl get all -n %NAMESPACE%
echo   kubectl get namespaces ^| findstr %NAMESPACE%

goto :eof

:show_help
echo n8n Minikube Cleanup Script for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   /y              Skip confirmation prompts
echo   --keep-image    Don't prompt to remove Docker image
echo   --help, -h, /?  Show this help message
echo.
echo Description:
echo   This script removes all n8n resources from Minikube:
echo   1. Deletes Kubernetes resources (services, deployment, etc.)
echo   2. Removes namespace
echo   3. Optionally removes Docker image
echo.
echo Examples:
echo   %~nx0
echo   %~nx0 /y
echo   %~nx0 /y --keep-image
echo.
goto :eof
