#!/bin/bash

# Convenience script to set Docker environment and start Tilt
# Usage: script/tilt-start.sh

set -e

echo "🚀 Setting up Tilt development environment..."

# Ensure we're in minikube context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "minikube" ]; then
    echo "❌ Not in minikube context. Run script/dev.sh first."
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi

echo "🔧 Setting minikube Docker environment..."
eval $(minikube docker-env)

echo "✅ Docker environment configured for minikube"
echo "🎯 Starting Tilt..."
echo ""

# Run Tilt directly with the environment set
exec tilt up