#!/bin/bash

# Stop port-forward process
# Usage: script/stop-port-forward.sh

set -e

# Check if PID file exists
if [ -f .port-forward.pid ]; then
  PID=$(cat .port-forward.pid)

  if kill -0 $PID 2>/dev/null; then
    echo "🛑 Stopping port-forward (PID: $PID)..."
    kill $PID
    echo "✅ Port-forward stopped"
  else
    echo "ℹ️  Port-forward process not running"
  fi

  rm -f .port-forward.pid
else
  echo "ℹ️  No port-forward PID file found"
fi

# Also kill any kubectl port-forward processes just in case
pkill -f "kubectl.*port-forward" 2>/dev/null && echo "🧹 Cleaned up any other port-forward processes" || true