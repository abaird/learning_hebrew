#!/bin/bash
# Bootstrap script: Start minikube and deploy all resources from scratch

set -e  # Exit on error

echo "🚀 Starting minikube bootstrap..."

# 1. Start minikube if not running
echo "📦 Starting minikube..."
minikube start

# 2. Configure Docker environment
echo "🔧 Configuring Docker environment for minikube..."
eval $(minikube -p minikube docker-env)

# 3. Build Docker image
echo "🏗️  Building Docker image..."
docker build -t learning-hebrew:local .

# 4. Deploy Kubernetes resources
echo "☸️  Deploying Kubernetes resources..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets-local.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/local/rails-app-local.yaml
kubectl apply -f k8s/ingress.yaml

# 5. Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n learning-hebrew --timeout=300s
kubectl wait --for=condition=ready pod -l app=learning-hebrew-app -n learning-hebrew --timeout=300s

# 6. Show status
echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📊 Current status:"
kubectl get pods -n learning-hebrew

echo ""
echo "🔌 To access the application, run:"
echo "   kubectl port-forward service/learning-hebrew-service 3000:80 -n learning-hebrew"
echo ""
echo "   Then visit: http://localhost:3000"