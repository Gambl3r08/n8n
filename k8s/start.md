kubectl apply -f namespace.yaml


kubectl apply -f configmap.yaml -n n8n
kubectl apply -f secret.yaml -n n8n
kubectl apply -f persistent-volume.yaml -n n8n
kubectl apply -f deployment.yaml -n n8n
kubectl apply -f service.yaml -n n8n


kubectl get all -n n8n

minikube service n8n-nodeport -n n8n
