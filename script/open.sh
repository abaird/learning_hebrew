#!/bin/bash

# Open the Rails app in the browser
# Usage: script/open.sh

set -e

# Check if learning-hebrew service exists
SERVICE=$(kubectl get service learning-hebrew-service -n learning-hebrew -o name 2>/dev/null || echo "")

if [ -z "$SERVICE" ]; then
  echo "❌ No learning-hebrew-service found. Is the app running?"
  echo "   Try: kubectl get services -n learning-hebrew"
  exit 1
fi

echo "🌐 Opening Rails app in browser..."

# Start port-forward if not already running
if [ ! -f .port-forward.pid ] || ! kill -0 $(cat .port-forward.pid 2>/dev/null) 2>/dev/null; then
  echo "🔌 Starting port-forward..."
  script/port-forward.sh 3000
fi

# Open browser
echo "🚀 Opening http://localhost:3000 in browser..."
open http://localhost:3000