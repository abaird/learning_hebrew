#!/bin/bash

# Switch to minikube development environment
# Usage: script/dev.sh

set -e

echo "🔄 Switching to DEVELOPMENT environment (minikube)..."

# Stop any existing port-forward first
echo "🛑 Stopping any existing port-forward..."
script/stop-port-forward.sh 2>/dev/null || true

# Switch kubectl context to minikube
kubectl config use-context minikube

# Verify the switch was successful
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" = "minikube" ]; then
    echo "✅ Successfully switched to minikube context"
    echo "🔧 Environment: DEVELOPMENT"
    echo "🗄️  Database: learning_hebrew_development"

    # Auto-start port forwarding for development convenience
    echo ""
    echo "🔌 Starting port-forward for development..."
    script/port-forward.sh 3000

    echo ""
    echo "💡 Available commands:"
    echo "   script/open.sh          - Open app in browser"
    echo "   script/logs.sh          - View app logs"
    echo "   script/stop-port-forward.sh - Stop port forwarding"
    echo "   kubectl get pods -n learning-hebrew"
else
    echo "❌ Failed to switch to minikube context"
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi