#!/bin/bash

# GKE Deployment Script for Learning Hebrew App
set -e

PROJECT_ID="your-project-id"  # Replace with your GCP project ID
CLUSTER_NAME="learning-hebrew-cluster"
REGION="us-central1"
IMAGE_NAME="learning-hebrew"

echo "Building and pushing Docker image..."
# Build and tag the image
docker build -t gcr.io/$PROJECT_ID/$IMAGE_NAME:latest .

# Push to Google Container Registry
docker push gcr.io/$PROJECT_ID/$IMAGE_NAME:latest

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