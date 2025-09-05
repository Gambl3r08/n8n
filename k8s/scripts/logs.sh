#!/bin/bash

# View n8n logs in Minikube
# Author: AI Assistant
# Description: Script to view n8n pod logs with options

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="n8n"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get pod name
get_pod_name() {
    kubectl get pods -n ${NAMESPACE} -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --follow     Follow log output (like tail -f)"
    echo "  -l, --lines N    Show last N lines (default: 100)"
    echo "  -s, --since      Show logs since timestamp (e.g., 5m, 1h, 2023-01-01T00:00:00Z)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Show last 100 lines"
    echo "  $0 -f                 # Follow logs in real-time"
    echo "  $0 -l 50              # Show last 50 lines"
    echo "  $0 -s 10m             # Show logs from last 10 minutes"
    echo "  $0 -f -s 5m           # Follow logs from last 5 minutes"
}

# Main function
main() {
    local follow=false
    local lines=100
    local since=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow=true
                shift
                ;;
            -l|--lines)
                lines="$2"
                shift 2
                ;;
            -s|--since)
                since="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Getting n8n pod logs..."
    
    # Get pod name
    POD_NAME=$(get_pod_name)
    
    if [[ -z "$POD_NAME" ]]; then
        print_error "No n8n pod found in namespace ${NAMESPACE}"
        print_status "Available pods:"
        kubectl get pods -n ${NAMESPACE}
        exit 1
    fi
    
    print_success "Found pod: $POD_NAME"
    
    # Build kubectl logs command
    cmd="kubectl logs $POD_NAME -n ${NAMESPACE}"
    
    if [[ "$follow" == true ]]; then
        cmd="$cmd -f"
    fi
    
    if [[ -n "$since" ]]; then
        cmd="$cmd --since=$since"
    else
        cmd="$cmd --tail=$lines"
    fi
    
    print_status "Executing: $cmd"
    echo ""
    
    # Execute the command
    eval $cmd
}

# Run main function
main "$@"
