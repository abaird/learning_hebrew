#!/bin/bash

# Port forward Rails app (runs in background)
# Usage: script/port-forward.sh [port]

set -e

PORT=${1:-3000}

# Check if service exists
SERVICE=$(kubectl get service learning-hebrew-service -n learning-hebrew -o name 2>/dev/null || echo "")

if [ -z "$SERVICE" ]; then
  echo "❌ No learning-hebrew-service found. Is the app running?"
  echo "   Try: kubectl get services -n learning-hebrew"
  exit 1
fi

# Kill any existing port-forward on this port
echo "🧹 Cleaning up any existing port-forward on port $PORT..."
pkill -f "kubectl.*port-forward.*$PORT" 2>/dev/null || true

# Start port-forward in background
echo "🔌 Starting port-forward on localhost:$PORT..."
kubectl port-forward service/learning-hebrew-service $PORT:80 -n learning-hebrew > /dev/null 2>&1 &

# Get the PID and save it
PID=$!
echo $PID > .port-forward.pid

# Wait a moment for port-forward to establish
sleep 2

# Check if it's working
if kill -0 $PID 2>/dev/null; then
  echo "✅ Port-forward running in background (PID: $PID)"
  echo "🌐 Rails app available at: http://localhost:$PORT"
  echo ""
  echo "To stop port-forward: script/stop-port-forward.sh"
else
  echo "❌ Port-forward failed to start"
  exit 1
fi