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

# Get the current DATABASE_URL and modify it for test environment
CURRENT_DATABASE_URL=$(kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- env | grep "DATABASE_URL=" | cut -d= -f2-)
TEST_DATABASE_URL=$(echo "$CURRENT_DATABASE_URL" | sed 's/learning_hebrew_development/learning_hebrew_test/')

echo "📦 Creating test database if needed..."
kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- \
    env RAILS_ENV=test DATABASE_URL="$TEST_DATABASE_URL" \
    bundle exec rails db:create db:schema:load

echo "🏃 Running RSpec tests..."
kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- \
    env RAILS_ENV=test DATABASE_URL="$TEST_DATABASE_URL" \
    bundle exec rspec "$@"

echo "✅ Tests completed!"