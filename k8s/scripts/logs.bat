@echo off
REM View n8n logs in Minikube - Batch Version
REM Author: AI Assistant
REM Description: Script to view n8n pod logs (Windows CMD)

setlocal EnableDelayedExpansion

REM Configuration
set NAMESPACE=n8n
set DEFAULT_LINES=100

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

REM Parse command line arguments
set FOLLOW=false
set LINES=%DEFAULT_LINES%
set SINCE=

:parse_args
if "%1"=="--help" goto show_help
if "%1"=="-h" goto show_help
if "%1"=="/?" goto show_help
if "%1"=="-f" (
    set FOLLOW=true
    shift
    goto parse_args
)
if "%1"=="--follow" (
    set FOLLOW=true
    shift
    goto parse_args
)
if "%1"=="-l" (
    set LINES=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--lines" (
    set LINES=%2
    shift
    shift
    goto parse_args
)
if "%1"=="-s" (
    set SINCE=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--since" (
    set SINCE=%2
    shift
    shift
    goto parse_args
)
if not "%1"=="" (
    call :print_error "Unknown option: %1"
    goto show_help
)

REM Main execution
call :print_status "Getting n8n pod logs..."
echo Platform: Windows Command Prompt
echo.

REM Get pod name
for /f "tokens=*" %%i in ('kubectl get pods -n %NAMESPACE% -l app=n8n -o jsonpath^=^{.items[0].metadata.name^} 2^>nul') do set POD_NAME=%%i

if "%POD_NAME%"=="" (
    call :print_error "No n8n pod found in namespace '%NAMESPACE%'"
    call :print_status "Available pods:"
    kubectl get pods -n %NAMESPACE%
    exit /b 1
)

call :print_success "Found pod: %POD_NAME%"

REM Build kubectl logs command
set KUBECTL_CMD=kubectl logs %POD_NAME% -n %NAMESPACE%

if "%FOLLOW%"=="true" (
    set KUBECTL_CMD=!KUBECTL_CMD! -f
)

if not "%SINCE%"=="" (
    set KUBECTL_CMD=!KUBECTL_CMD! --since=%SINCE%
) else (
    set KUBECTL_CMD=!KUBECTL_CMD! --tail=%LINES%
)

call :print_status "Executing: %KUBECTL_CMD%"
echo.

REM Execute the command
%KUBECTL_CMD%
if errorlevel 1 (
    call :print_error "Failed to get logs"
    echo.
    echo Troubleshooting tips:
    echo 1. Check if the pod is running: kubectl get pods -n %NAMESPACE%
    echo 2. Check pod status: kubectl describe pod %POD_NAME% -n %NAMESPACE%
    echo 3. Check deployment status: scripts\status.bat
    exit /b 1
)

goto :eof

:show_help
echo n8n Logs Viewer for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   -f, --follow     Follow log output (like tail -f)
echo   -l, --lines N    Show last N lines (default: %DEFAULT_LINES%)
echo   -s, --since      Show logs since timestamp (e.g., 5m, 1h)
echo   --help, -h, /?   Show this help message
echo.
echo Examples:
echo   %~nx0                    # Show last %DEFAULT_LINES% lines
echo   %~nx0 -f                 # Follow logs in real-time
echo   %~nx0 -l 50              # Show last 50 lines
echo   %~nx0 -s 10m             # Show logs from last 10 minutes
echo   %~nx0 -f -s 5m           # Follow logs from last 5 minutes
echo.
goto :eof
