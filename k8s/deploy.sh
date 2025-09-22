#!/bin/bash

# GKE Deployment Script for Learning Hebrew App
set -e

PROJECT_ID="learning-hebrew-1758491674"
CLUSTER_NAME="learning-hebrew-cluster"
REGION="us-central1"
IMAGE_NAME="learning-hebrew"

echo "Setting up Artifact Registry..."
# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID

# Create repository if it doesn't exist
gcloud artifacts repositories create $IMAGE_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Learning Hebrew Rails app" \
    --project=$PROJECT_ID 2>/dev/null || echo "Repository already exists"

echo "Building and pushing Docker image..."
# Build and tag the image for Artifact Registry
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest .

# Push to Artifact Registry
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest

echo "Creating GKE Autopilot cluster..."
gcloud container clusters create-auto $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

echo "Creating static IP..."
gcloud compute addresses create learning-hebrew-ip --global --project=$PROJECT_ID

echo "Deploying to Kubernetes..."
# Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/rails-app.yaml
kubectl apply -f k8s/ingress.yaml

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/learning-hebrew-app -n learning-hebrew

echo "Getting external IP..."
kubectl get ingress learning-hebrew-ingress -n learning-hebrew

echo "Deployment complete! Update your DNS to point to the external IP shown above."