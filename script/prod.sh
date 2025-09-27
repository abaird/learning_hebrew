#!/bin/bash

# Switch to GKE production environment
# Usage: script/prod.sh

set -e

echo "🔄 Switching to PRODUCTION environment (GKE)..."

# Stop any existing port-forward first
echo "🛑 Stopping any existing port-forward..."
script/stop-port-forward.sh 2>/dev/null || true

# Switch kubectl context to GKE
kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster

# Verify the switch was successful
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" = "gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster" ]; then
    echo "✅ Successfully switched to GKE context"
    echo "🏭 Environment: PRODUCTION"
    echo "🗄️  Database: learning_hebrew_production"
    echo "🌐 Domain: learning-hebrew.bairdsnet.net"
    echo ""
    echo "💡 Available commands:"
    echo "   script/logs.sh          - View production logs"
    echo "   script/port-forward.sh  - Debug via port forwarding"
    echo "   kubectl get pods -n learning-hebrew"
    echo ""
    echo "⚠️  WARNING: You are now connected to PRODUCTION!"
    echo "ℹ️  Note: Port forwarding NOT auto-started for production safety"
else
    echo "❌ Failed to switch to GKE context"
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi