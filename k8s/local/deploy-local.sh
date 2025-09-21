#!/bin/bash

# Local Kubernetes deployment script
set -e

echo "Skipping Docker build (run 'docker build -t learning-hebrew:local .' manually first)"

echo "Loading image into minikube..."
minikube image load learning-hebrew:local

echo "Deploying to local Kubernetes..."
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply local configs
kubectl apply -f k8s/local/secrets-local.yaml
kubectl apply -f k8s/local/configmap-local.yaml
kubectl apply -f k8s/local/postgres-local.yaml

# Wait for postgres to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/postgres -n learning-hebrew

# Deploy Rails app
kubectl apply -f k8s/local/rails-app-local.yaml

echo "Waiting for Rails app to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/learning-hebrew-app -n learning-hebrew

echo "Getting service info..."
kubectl get pods -n learning-hebrew
kubectl get services -n learning-hebrew

echo ""
echo "To access your app:"
echo "  minikube service learning-hebrew-service -n learning-hebrew"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/learning-hebrew-app -n learning-hebrew"