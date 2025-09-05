# Makefile for n8n Minikube deployment
# Author: AI Assistant

.PHONY: help install build deploy clean status logs shell port-forward dashboard

# Default target
help: ## Show this help message
	@echo "n8n Minikube Deployment Commands"
	@echo "================================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Prerequisites
check-deps: ## Check if all required tools are installed
	@echo "Checking dependencies..."
	@which docker > /dev/null || (echo "❌ Docker not found" && exit 1)
	@which minikube > /dev/null || (echo "❌ Minikube not found" && exit 1)
	@which kubectl > /dev/null || (echo "❌ kubectl not found" && exit 1)
	@echo "✅ All dependencies are installed"

start-minikube: ## Start Minikube cluster
	@echo "Starting Minikube..."
	@minikube start --driver=docker --memory=4096 --cpus=2
	@echo "✅ Minikube started successfully"

##@ Build and Deploy
build: ## Build n8n Docker image
	@echo "Building n8n Docker image..."
	@eval $$(minikube docker-env) && docker build -t n8n-local:latest -f Dockerfile ..
	@echo "✅ Image built successfully"

deploy: ## Deploy n8n to Minikube
	@echo "Deploying n8n to Minikube..."
	@kubectl apply -f namespace.yaml
	@kubectl apply -f configmap.yaml
	@kubectl apply -f secret.yaml
	@kubectl apply -f persistent-volume.yaml
	@kubectl apply -f deployment.yaml
	@kubectl apply -f service.yaml
	@kubectl wait --for=condition=available --timeout=300s deployment/n8n-deployment -n n8n
	@echo "✅ n8n deployed successfully"

install: check-deps start-minikube build deploy ## Complete installation (check deps, start minikube, build, deploy)
	@echo "🎉 n8n is now running on Minikube!"
	@echo "Access methods:"
	@echo "1. Port forward: make port-forward"
	@echo "2. Minikube service: minikube service n8n-nodeport -n n8n"
	@echo "3. Direct access: http://$$(minikube ip):30678"
	@echo ""
	@echo "Default credentials:"
	@echo "Username: admin"
	@echo "Password: password123"

##@ Management
status: ## Show deployment status
	@./scripts/status.sh

logs: ## Show n8n logs
	@./scripts/logs.sh

logs-follow: ## Follow n8n logs in real-time
	@./scripts/logs.sh -f

shell: ## Get shell access to n8n pod
	@kubectl exec -it $$(kubectl get pods -n n8n -l app=n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- /bin/sh

##@ Access
port-forward: ## Create port forward to access n8n locally
	@echo "Creating port forward to n8n service..."
	@echo "Access n8n at: http://localhost:5678"
	@echo "Press Ctrl+C to stop"
	@kubectl port-forward service/n8n-service 5678:5678 -n n8n

dashboard: ## Open Kubernetes dashboard
	@minikube dashboard

##@ Cleanup
clean: ## Remove n8n deployment
	@echo "Cleaning up n8n deployment..."
	@./scripts/cleanup.sh
	@echo "✅ Cleanup completed"

clean-all: clean ## Remove deployment and stop Minikube
	@echo "Stopping Minikube..."
	@minikube stop
	@echo "✅ Minikube stopped"

##@ Development
rebuild: ## Rebuild and redeploy n8n
	@echo "Rebuilding and redeploying n8n..."
	@eval $$(minikube docker-env) && docker build -t n8n-local:latest -f Dockerfile ..
	@kubectl rollout restart deployment/n8n-deployment -n n8n
	@kubectl wait --for=condition=available --timeout=300s deployment/n8n-deployment -n n8n
	@echo "✅ n8n rebuilt and redeployed"

update-config: ## Update configuration (restart deployment)
	@echo "Updating configuration..."
	@kubectl apply -f configmap.yaml
	@kubectl apply -f secret.yaml
	@kubectl rollout restart deployment/n8n-deployment -n n8n
	@echo "✅ Configuration updated"

##@ Monitoring
top: ## Show resource usage
	@kubectl top pods -n n8n

events: ## Show recent events
	@kubectl get events -n n8n --sort-by='.lastTimestamp'

describe: ## Describe n8n deployment
	@kubectl describe deployment n8n-deployment -n n8n

##@ Backup
backup: ## Create backup of n8n data
	@echo "Creating backup..."
	@kubectl exec -it $$(kubectl get pods -n n8n -l app=n8n -o jsonpath='{.items[0].metadata.name}') -n n8n -- tar -czf /tmp/backup.tar.gz /home/n8n/.n8n
	@kubectl cp n8n/$$(kubectl get pods -n n8n -l app=n8n -o jsonpath='{.items[0].metadata.name}'):/tmp/backup.tar.gz ./n8n-backup-$$(date +%Y%m%d-%H%M%S).tar.gz -n n8n
	@echo "✅ Backup created: n8n-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"
