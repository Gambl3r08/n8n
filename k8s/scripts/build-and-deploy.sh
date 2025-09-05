#!/bin/bash

# Build and Deploy n8n to Minikube
# Author: AI Assistant
# Description: Complete automation script for n8n deployment in Minikube

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="n8n"
IMAGE_NAME="n8n-local"
IMAGE_TAG="latest"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists minikube; then
        print_error "Minikube is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

# Start Minikube if not running
start_minikube() {
    print_status "Checking Minikube status..."
    
    if ! minikube status >/dev/null 2>&1; then
        print_status "Starting Minikube..."
        minikube start --driver=docker --memory=4096 --cpus=2
        print_success "Minikube started successfully."
    else
        print_success "Minikube is already running."
    fi
}

# Configure Docker environment
configure_docker_env() {
    print_status "Configuring Docker environment for Minikube..."
    eval $(minikube docker-env)
    print_success "Docker environment configured."
}

# Build Docker image
build_image() {
    print_status "Building n8n Docker image..."
    
    # Change to project root (assuming script is in k8s/scripts/)
    cd "$(dirname "$0")/../.."
    
    # Build the image using the Dockerfile in k8s/
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f k8s/Dockerfile .
    
    print_success "Docker image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
}

# Apply Kubernetes manifests
apply_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    # Change to k8s directory
    cd "$(dirname "$0")/.."
    
    # Apply manifests in order
    kubectl apply -f namespace.yaml
    kubectl apply -f configmap.yaml
    kubectl apply -f secret.yaml
    kubectl apply -f persistent-volume.yaml
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    
    print_success "All manifests applied successfully."
}

# Wait for deployment to be ready
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/n8n-deployment -n ${NAMESPACE}
    print_success "Deployment is ready."
}

# Get service information
get_service_info() {
    print_status "Getting service information..."
    
    echo ""
    echo "=== n8n Service Information ==="
    kubectl get services -n ${NAMESPACE}
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n ${NAMESPACE}
    
    echo ""
    echo "=== Access URLs ==="
    echo "1. Using kubectl port-forward:"
    echo "   kubectl port-forward service/n8n-service 5678:5678 -n ${NAMESPACE}"
    echo "   Then open: http://localhost:5678"
    echo ""
    echo "2. Using minikube service:"
    echo "   minikube service n8n-nodeport -n ${NAMESPACE}"
    echo ""
    echo "3. Direct NodePort access:"
    MINIKUBE_IP=$(minikube ip)
    echo "   http://${MINIKUBE_IP}:30678"
    echo ""
    echo "=== Default Credentials ==="
    echo "Username: admin"
    echo "Password: password123"
    echo ""
}

# Main execution
main() {
    print_status "Starting n8n deployment to Minikube..."
    
    check_prerequisites
    start_minikube
    configure_docker_env
    build_image
    apply_manifests
    wait_for_deployment
    get_service_info
    
    print_success "n8n has been successfully deployed to Minikube!"
    print_warning "Note: This is a development setup. For production, configure proper secrets and persistent storage."
}

# Run main function
main "$@"
