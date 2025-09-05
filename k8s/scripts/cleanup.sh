#!/bin/bash

# Cleanup n8n deployment from Minikube
# Author: AI Assistant
# Description: Script to remove all n8n resources from Minikube

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

# Main cleanup function
cleanup_n8n() {
    print_status "Starting n8n cleanup from Minikube..."
    
    if ! namespace_exists ${NAMESPACE}; then
        print_warning "Namespace ${NAMESPACE} does not exist. Nothing to cleanup."
        return
    fi
    
    print_status "Deleting n8n resources..."
    
    # Change to k8s directory
    cd "$(dirname "$0")/.."
    
    # Delete resources in reverse order
    kubectl delete -f service.yaml --ignore-not-found=true
    kubectl delete -f deployment.yaml --ignore-not-found=true
    kubectl delete -f persistent-volume.yaml --ignore-not-found=true
    kubectl delete -f secret.yaml --ignore-not-found=true
    kubectl delete -f configmap.yaml --ignore-not-found=true
    kubectl delete -f namespace.yaml --ignore-not-found=true
    
    print_success "All n8n resources have been deleted."
    
    # Optional: Remove Docker image
    read -p "Do you want to remove the Docker image as well? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Configuring Docker environment..."
        eval $(minikube docker-env)
        
        print_status "Removing Docker image..."
        docker rmi n8n-local:latest --force 2>/dev/null || print_warning "Docker image not found or already removed."
        print_success "Docker image removed."
    fi
    
    print_success "Cleanup completed successfully!"
}

# Main execution
cleanup_n8n "$@"
