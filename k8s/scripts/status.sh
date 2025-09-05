#!/bin/bash

# Check n8n deployment status in Minikube
# Author: AI Assistant
# Description: Script to check the status of n8n deployment

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

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Function to get pod status
get_pod_status() {
    kubectl get pods -n ${NAMESPACE} -l app=n8n -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound"
}

# Function to check service accessibility
check_service_access() {
    print_status "Checking service accessibility..."
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "unknown")
    
    echo ""
    echo "=== Access Methods ==="
    echo "1. Port Forward (recommended for development):"
    echo "   kubectl port-forward service/n8n-service 5678:5678 -n ${NAMESPACE}"
    echo "   Then open: http://localhost:5678"
    echo ""
    echo "2. NodePort Service:"
    echo "   minikube service n8n-nodeport -n ${NAMESPACE}"
    echo ""
    echo "3. Direct NodePort URL:"
    echo "   http://${MINIKUBE_IP}:30678"
    echo ""
    
    # Test if service is responding
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$POD_NAME" ]]; then
        print_status "Testing service health..."
        if kubectl exec -n ${NAMESPACE} "$POD_NAME" -- wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
            print_success "Service is healthy and responding"
        else
            print_warning "Service may not be fully ready yet"
        fi
    fi
}

# Main status check function
check_status() {
    print_status "Checking n8n deployment status in Minikube..."
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        print_error "Minikube is not running. Please start it with: minikube start"
        return 1
    fi
    
    print_success "Minikube is running"
    
    # Check if namespace exists
    if ! namespace_exists ${NAMESPACE}; then
        print_error "Namespace ${NAMESPACE} does not exist. n8n is not deployed."
        return 1
    fi
    
    print_success "Namespace ${NAMESPACE} exists"
    
    echo ""
    echo "=== Deployment Status ==="
    kubectl get deployments -n ${NAMESPACE}
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n ${NAMESPACE} -o wide
    
    echo ""
    echo "=== Service Status ==="
    kubectl get services -n ${NAMESPACE}
    
    echo ""
    echo "=== ConfigMap and Secrets ==="
    kubectl get configmaps,secrets -n ${NAMESPACE}
    
    echo ""
    echo "=== Persistent Volumes ==="
    kubectl get pv,pvc -n ${NAMESPACE}
    
    # Check pod status
    POD_STATUS=$(get_pod_status)
    echo ""
    echo "=== Pod Health ==="
    case $POD_STATUS in
        "Running")
            print_success "Pod is running"
            ;;
        "Pending")
            print_warning "Pod is pending (may be starting up)"
            ;;
        "Failed"|"Error")
            print_error "Pod has failed"
            ;;
        "NotFound")
            print_error "No n8n pods found"
            ;;
        *)
            print_warning "Pod status: $POD_STATUS"
            ;;
    esac
    
    # Show recent events
    echo ""
    echo "=== Recent Events ==="
    kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10
    
    # Check service accessibility
    if [[ "$POD_STATUS" == "Running" ]]; then
        check_service_access
    fi
    
    echo ""
    echo "=== Default Credentials ==="
    echo "Username: admin"
    echo "Password: password123"
    echo ""
    
    print_status "Status check completed."
}

# Main execution
check_status "$@"
