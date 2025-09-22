#!/bin/bash

# Follow Rails logs in Kubernetes
# Usage: script/logs.sh [--init] [--previous]

set -e

CONTAINER="rails-app"
FOLLOW_FLAG="-f"
PREVIOUS_FLAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --init)
      CONTAINER="db-migrate"
      shift
      ;;
    --previous|-p)
      PREVIOUS_FLAG="--previous"
      FOLLOW_FLAG=""  # Can't follow previous logs
      shift
      ;;
    --help|-h)
      echo "Usage: script/logs.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --init      Show init container (db-migrate) logs"
      echo "  --previous  Show logs from previous container restart"
      echo "  --help      Show this help message"
      echo ""
      echo "Examples:"
      echo "  script/logs.sh           # Follow current Rails app logs"
      echo "  script/logs.sh --init    # Show database migration logs"
      echo "  script/logs.sh -p        # Show previous Rails app logs"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Find the Rails pod
POD=$(kubectl get pods -n learning-hebrew -l app=learning-hebrew-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
  echo "❌ No Rails pod found. Is the app running?"
  echo "   Try: kubectl get pods"
  exit 1
fi

echo "📋 Showing $CONTAINER logs from pod: $POD"
if [ -n "$PREVIOUS_FLAG" ]; then
  echo "   (Previous container restart)"
fi
echo "   Use Ctrl+C to exit"
echo ""

# Show logs
kubectl logs $FOLLOW_FLAG $PREVIOUS_FLAG "$POD" -n learning-hebrew -c "$CONTAINER"