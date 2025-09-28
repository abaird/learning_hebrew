#!/bin/bash

# Start Tilt development environment
# Usage: script/tilt.sh

set -e

echo "🚀 Starting Tilt development environment..."

# Ensure we're in minikube context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "minikube" ]; then
    echo "❌ Not in minikube context. Run script/dev.sh first."
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi

# Check if minikube Docker environment is set
if [ -z "$MINIKUBE_ACTIVE_DOCKERD" ]; then
    echo ""
    echo "🔧 Docker environment not set for minikube!"
    echo "💡 Please run this in your terminal first:"
    echo ""
    echo "   eval \$(minikube docker-env)"
    echo "   script/tilt.sh"
    echo ""
    echo "   Or run them together:"
    echo "   eval \$(minikube docker-env) && script/tilt.sh"
    echo ""
    exit 1
fi

# Stop any existing port-forwards to avoid conflicts
echo "🛑 Stopping any existing port-forwards..."
script/stop-port-forward.sh 2>/dev/null || true

# Start Tilt
echo "🎯 Starting Tilt (Ctrl+C to stop)..."
echo "📊 Tilt UI will be available at: http://localhost:10350"
echo ""

# Run Tilt (this blocks until Ctrl+C)
tilt up

# Cleanup message
echo ""
echo "🛑 Tilt stopped. Port forwards may still be active."
echo "💡 To manually stop all: script/stop-port-forward.sh"