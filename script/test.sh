#!/bin/bash

# Run RSpec tests in minikube with proper test environment
# Usage: script/test.sh [rspec-options]

set -e

echo "🧪 Running tests in minikube (test environment)..."

# Ensure we're on minikube context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "minikube" ]; then
    echo "❌ Not on minikube context. Run 'script/dev.sh' first."
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi

# Check if pods are running
if ! kubectl get pods -n learning-hebrew | grep -q "learning-hebrew-app.*Running"; then
    echo "❌ Rails app not running in minikube."
    echo "   Run 'script/dev.sh' to start the development environment."
    exit 1
fi

echo "🔧 Setting up test database..."

echo "📦 Creating test database if needed..."
kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- \
    env RAILS_ENV=test DATABASE_NAME=learning_hebrew_test \
    bundle exec rails db:create db:schema:load

echo "🏃 Running RSpec tests..."
kubectl exec -it deployment/learning-hebrew-app -n learning-hebrew -- \
    env RAILS_ENV=test DATABASE_NAME=learning_hebrew_test FORCE_COLOR=1 \
    bundle exec rspec "$@"

echo "✅ Tests completed!"