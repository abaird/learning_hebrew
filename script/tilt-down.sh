#!/bin/bash

# Stop Tilt and cleanup
# Usage: script/tilt-down.sh

set -e

echo "🛑 Stopping Tilt development environment..."

# Use Tilt's proper shutdown command
tilt down && echo "✅ Tilt resources stopped" || echo "ℹ️  Tilt down completed (or no resources found)"

# Stop any remaining port forwards as backup
script/stop-port-forward.sh 2>/dev/null || true

echo "✅ Tilt development environment stopped"
echo "💡 To restart: script/tilt.sh"