#!/bin/bash

# Connect to Rails console in Kubernetes
# Usage: script/rails.sh [console|dbconsole|c|db]

set -e

# Default to console if no argument provided
COMMAND=${1:-console}

# Handle common aliases
case $COMMAND in
  c|console)
    RAILS_COMMAND="console"
    ;;
  db|dbconsole)
    RAILS_COMMAND="dbconsole"
    ;;
  *)
    RAILS_COMMAND="$COMMAND"
    ;;
esac

# Find the Rails pod
POD=$(kubectl get pods -n learning-hebrew -l app=learning-hebrew-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
  echo "❌ No Rails pod found. Is the app running?"
  echo "   Try: kubectl get pods"
  exit 1
fi

echo "🚀 Starting Rails $RAILS_COMMAND in pod: $POD"
echo "   Use 'exit' to return to your terminal"
echo ""

# Run Rails command in the rails-app container
kubectl exec -it "$POD" -n learning-hebrew -c rails-app -- bin/rails "$RAILS_COMMAND"