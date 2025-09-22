#!/bin/bash

# Connect to the Rails container in Kubernetes
# Usage: script/container.sh

set -e

# Find the Rails pod
POD=$(kubectl get pods -n learning-hebrew -l app=learning-hebrew-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
  echo "❌ No Rails pod found. Is the app running?"
  echo "   Try: kubectl get pods"
  exit 1
fi

echo "🚀 Connecting to Rails container in pod: $POD"
echo "   Use 'exit' to return to your terminal"
echo ""

# Connect to the rails-app container (not the init container)
kubectl exec -it "$POD" -n learning-hebrew -c rails-app -- /bin/bash