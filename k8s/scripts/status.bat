@echo off
REM Check n8n deployment status in Minikube - Batch Version
REM Author: AI Assistant
REM Description: Script to check the status of n8n deployment (Windows CMD)

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
call :print_status "Checking n8n deployment status in Minikube..."
echo Platform: Windows Command Prompt
echo.

REM Check if Minikube is running
minikube status >nul 2>&1
if errorlevel 1 (
    call :print_error "Minikube is not running. Please start it with: minikube start"
    exit /b 1
)

call :print_success "Minikube is running"

REM Check if namespace exists
kubectl get namespace %NAMESPACE% >nul 2>&1
if errorlevel 1 (
    call :print_error "Namespace '%NAMESPACE%' does not exist. n8n is not deployed."
    echo To deploy n8n, run: scripts\build-and-deploy.bat
    exit /b 1
)

call :print_success "Namespace '%NAMESPACE%' exists"

echo.
echo === Deployment Status ===
kubectl get deployments -n %NAMESPACE%

echo.
echo === Pod Status ===
kubectl get pods -n %NAMESPACE% -o wide

echo.
echo === Service Status ===
kubectl get services -n %NAMESPACE%

echo.
echo === ConfigMap and Secrets ===
kubectl get configmaps,secrets -n %NAMESPACE%

echo.
echo === Persistent Volumes ===
kubectl get pv,pvc -n %NAMESPACE%

REM Check pod status
for /f "tokens=*" %%i in ('kubectl get pods -n %NAMESPACE% -l app=n8n -o jsonpath^=^{.items[0].status.phase^} 2^>nul') do set POD_STATUS=%%i

echo.
echo === Pod Health ===
if "%POD_STATUS%"=="Running" (
    call :print_success "Pod is running"
    set SERVICE_READY=true
) else if "%POD_STATUS%"=="Pending" (
    call :print_warning "Pod is pending (may be starting up)"
    set SERVICE_READY=false
) else if "%POD_STATUS%"=="Failed" (
    call :print_error "Pod has failed"
    set SERVICE_READY=false
) else if "%POD_STATUS%"=="Error" (
    call :print_error "Pod has error"
    set SERVICE_READY=false
) else if "%POD_STATUS%"=="" (
    call :print_error "No n8n pods found"
    set SERVICE_READY=false
) else (
    call :print_warning "Pod status: %POD_STATUS%"
    set SERVICE_READY=false
)

REM Show recent events
echo.
echo === Recent Events (last 5) ===
kubectl get events -n %NAMESPACE% --sort-by=.lastTimestamp | findstr /v "^$" | more +1 | powershell -command "Get-Content | Select-Object -Last 5"

REM Check service accessibility if pod is running
if "%SERVICE_READY%"=="true" (
    call :print_status "Checking service accessibility..."
    
    REM Get Minikube IP
    for /f "tokens=*" %%i in ('minikube ip 2^>nul') do set MINIKUBE_IP=%%i
    if "%MINIKUBE_IP%"=="" set MINIKUBE_IP=unknown
    
    echo.
    echo === Access Methods ===
    echo 1. Port Forward (recommended for development):
    echo    kubectl port-forward service/n8n-service 5678:5678 -n %NAMESPACE%
    echo    Then open: http://localhost:5678
    echo.
    echo 2. NodePort Service:
    echo    minikube service n8n-nodeport -n %NAMESPACE%
    echo.
    echo 3. Direct NodePort URL:
    echo    http://%MINIKUBE_IP%:30678
    echo.
    
    REM Test if service is responding
    for /f "tokens=*" %%i in ('kubectl get pods -n %NAMESPACE% -l app=n8n -o jsonpath^=^{.items[0].metadata.name^} 2^>nul') do set POD_NAME=%%i
    
    if not "%POD_NAME%"=="" (
        call :print_status "Testing service health..."
        kubectl exec -n %NAMESPACE% %POD_NAME% -- wget -q --spider http://localhost:5678/healthz >nul 2>&1
        if not errorlevel 1 (
            call :print_success "Service is healthy and responding"
        ) else (
            call :print_warning "Service may not be fully ready yet"
        )
    )
)

echo.
echo === Default Credentials ===
echo Username: admin
echo Password: password123
echo.

echo === Batch Management Commands ===
echo View logs:       scripts\logs.bat
echo Follow logs:     scripts\logs.bat -f
echo Cleanup:         scripts\cleanup.bat
echo Redeploy:        scripts\build-and-deploy.bat
echo.

call :print_status "Status check completed."
goto :eof

:show_help
echo n8n Status Checker for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   --help, -h, /?   Show this help message
echo.
echo Description:
echo   This script checks the current status of n8n deployment in Minikube:
echo   1. Verifies Minikube is running
echo   2. Checks namespace existence
echo   3. Shows deployment, pod, and service status
echo   4. Provides access information
echo   5. Shows recent events
echo.
echo Examples:
echo   %~nx0
echo.
goto :eof
