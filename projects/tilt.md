# Tilt Integration for Learning Hebrew App

## Overview

This guide implements Tilt for fast local development iteration in minikube, building on the existing Ruby on Rails 8 + Kubernetes infrastructure.

## Goals

- **Fast iteration cycles**: Automatic rebuilds and code reloading
- **Backwards compatibility**: Existing scripts (`script/dev.sh`, `script/prod.sh`) remain unchanged
- **Production isolation**: Tilt only operates in minikube context
- **Minimal cruft**: Reuse existing Docker and Kubernetes configurations

## Prerequisites

- Minikube running and configured
- Docker environment set for minikube: `eval $(minikube docker-env)`
- Existing project setup working with `script/dev.sh`

## Implementation Steps

### 1. Install Tilt

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# Linux
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# Windows (PowerShell)
iex ((new-object net.webclient).downloadstring('https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.ps1'))

# Verify installation
tilt version
```

### 2. Create Development Dockerfile

Create `Dockerfile.dev` (optimized for Tilt live-updates):

```dockerfile
# syntax=docker/dockerfile:1
# Dockerfile.dev - Optimized for Tilt development

ARG RUBY_VERSION=3.3.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Install base packages (same as production)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client watchman && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Development environment
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle"

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config nodejs npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy and install Node dependencies
COPY package.json package-lock.json* ./
RUN npm install

# Copy and install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile assets for development
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Create non-root user (same as production)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp app/assets/builds
USER 1000:1000

# Entrypoint and startup
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/dev"]
```

### 3. Create Tiltfile

Create `Tiltfile` in the project root:

```python
# Tiltfile for Learning Hebrew App
# Provides fast local development with minikube

# Ensure we're in minikube context for safety
expected_context = 'minikube'
actual_context = str(local('kubectl config current-context')).strip()
if actual_context != expected_context:
    fail('Expected kubectl context "%s", got "%s". Run script/dev.sh first.' % (expected_context, actual_context))

# Build the development Docker image with live-update capabilities
docker_build(
    'learning-hebrew:latest',
    context='.',
    dockerfile='./Dockerfile.dev',

    # Live update configuration for fast Ruby development
    live_update=[
        # Sync Ruby application code (skip rebuilds for code changes)
        sync('./app', '/rails/app'),
        sync('./config', '/rails/config'),
        sync('./lib', '/rails/lib'),
        sync('./spec', '/rails/spec'),

        # Sync view templates and assets
        sync('./app/views', '/rails/app/views'),
        sync('./app/assets', '/rails/app/assets'),

        # Restart Rails server when important files change
        restart_container(trigger=['./Gemfile', './Gemfile.lock', './config/routes.rb']),

        # Run commands inside container for certain changes
        run('bundle install', trigger=['./Gemfile', './Gemfile.lock']),
        run('SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile', trigger=['./app/assets/', './config/application.rb']),
    ],

    # Only rebuild image when Dockerfile or key dependencies change
    ignore=['.git', 'tmp/', 'log/', 'storage/', '.port-forward.pid', 'projects/']
)

# Apply Kubernetes manifests (reuse existing configurations)
k8s_yaml([
    'k8s/namespace.yaml',
    'k8s/configmap.yaml',
    'k8s/secrets-local.yaml',  # Use local secrets for development
    'k8s/postgres.yaml',
    'k8s/rails-app.yaml',
    'k8s/ingress.yaml'
])

# Configure Rails application resource
k8s_resource(
    workload='learning-hebrew-app',
    port_forwards=[
        port_forward(3000, 3000, name='rails-web'),  # Rails server
    ],

    # Resource dependencies (Postgres must be ready first)
    resource_deps=['postgres'],

    # Custom labels for organization
    labels=['backend', 'web']
)

# Configure PostgreSQL resource
k8s_resource(
    workload='postgres',
    port_forwards=[
        port_forward(5432, 5432, name='postgres-db'),  # Database access
    ],
    labels=['database']
)

# Health check and status monitoring
local_resource(
    'health-check',
    cmd='curl -f http://localhost:3000/up || echo "Waiting for Rails to start..."',
    resource_deps=['learning-hebrew-app'],
    labels=['monitoring']
)

# Optional: Add database reset command for development
local_resource(
    'db-reset',
    cmd='kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- bin/rails db:reset',
    trigger_mode=TRIGGER_MODE_MANUAL,
    resource_deps=['learning-hebrew-app'],
    labels=['database', 'manual']
)

print("🚀 Tilt configuration loaded!")
print("📱 Rails app: http://localhost:3000")
print("🗄️  PostgreSQL: localhost:5432")
print("💡 Run 'tilt up' to start development environment")
```

### 4. Create Tilt Scripts

Create `script/tilt.sh`:

```bash
#!/bin/bash

# Start Tilt development environment
# Usage: script/tilt.sh

set -e

echo "🚀 Starting Tilt development environment..."

# Ensure we're in minikube context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "minikube" ]; then
    echo "❌ Not in minikube context. Run script/dev.sh first."
    echo "   Current context: $CURRENT_CONTEXT"
    exit 1
fi

# Ensure minikube Docker environment is set
if [ -z "$MINIKUBE_ACTIVE_DOCKERD" ]; then
    echo "🔧 Setting minikube Docker environment..."
    eval $(minikube docker-env)
fi

# Stop any existing port-forwards to avoid conflicts
echo "🛑 Stopping any existing port-forwards..."
script/stop-port-forward.sh 2>/dev/null || true

# Start Tilt
echo "🎯 Starting Tilt (Ctrl+C to stop)..."
echo "📊 Tilt UI will be available at: http://localhost:10350"
echo ""

# Run Tilt (this blocks until Ctrl+C)
tilt up

# Cleanup message
echo ""
echo "🛑 Tilt stopped. Port forwards may still be active."
echo "💡 To manually stop all: script/stop-port-forward.sh"
```

Create `script/tilt-down.sh`:

```bash
#!/bin/bash

# Stop Tilt and cleanup
# Usage: script/tilt-down.sh

set -e

echo "🛑 Stopping Tilt development environment..."

# Kill Tilt processes
pkill -f "tilt up" 2>/dev/null && echo "✅ Tilt process stopped" || echo "ℹ️  No Tilt process found"

# Stop port forwards
script/stop-port-forward.sh 2>/dev/null || true

# Clean up Tilt resources (optional - keeps data by default)
# Uncomment the next line if you want to delete all resources on stop
# kubectl delete namespace learning-hebrew 2>/dev/null && echo "🗑️  Cleaned up Kubernetes resources" || true

echo "✅ Tilt development environment stopped"
echo "💡 To restart: script/tilt.sh"
```

Make scripts executable:

```bash
chmod +x script/tilt.sh script/tilt-down.sh
```

### 5. Update .gitignore

Add Tilt-specific ignores to `.gitignore`:

```gitignore
# Tilt
.tiltbuild/
tilt_modules/
```

### 6. Integration with Existing Scripts

The existing scripts remain unchanged and fully functional:

- **`script/dev.sh`**: Still switches to minikube and starts port-forwarding (non-Tilt)
- **`script/prod.sh`**: Still switches to production (Tilt automatically stops)
- **`script/port-forward.sh`**: Still works for manual port-forwarding
- **`script/test.sh`**: Still runs tests in isolated environment

### 7. Development Workflows

#### Option A: Traditional Workflow (Unchanged)
```bash
script/dev.sh          # Switch to minikube + port-forward
# Develop normally, manual rebuilds as needed
script/prod.sh         # Switch to production
```

#### Option B: Tilt-Enhanced Workflow (New)
```bash
script/dev.sh          # Switch to minikube context
script/tilt.sh         # Start Tilt for fast iteration
# Develop with automatic rebuilds and live-updates
# Ctrl+C to stop Tilt
script/prod.sh         # Switch to production
```

#### Option C: Mixed Workflow
```bash
script/dev.sh          # Start with traditional setup
# Do initial development/testing
script/tilt.sh         # Switch to Tilt when you need fast iteration
# Rapid development cycles
script/tilt-down.sh    # Stop Tilt
script/prod.sh         # Check production
```

## Tilt Benefits

### Fast Development Cycles
- **Code changes**: Live-updated in seconds (no rebuild)
- **Gem changes**: Automatic bundle install + container restart
- **Asset changes**: Automatic recompilation
- **Database changes**: Manual `db-reset` resource available

### Developer Experience
- **Unified logs**: All services in one Tilt UI
- **Visual status**: Service health at a glance
- **Port management**: Automatic forwarding
- **Real-time updates**: File watching and automatic actions

### Resource Management
- **Smart rebuilds**: Only rebuild when necessary
- **Efficient caching**: Docker layer caching optimized
- **Resource dependencies**: Postgres starts before Rails
- **Cleanup**: Easy stop/start without losing data

## Usage Tips

### Daily Development
```bash
# Morning startup
script/dev.sh && script/tilt.sh

# Work normally - Tilt handles rebuilds automatically

# Evening shutdown
# Ctrl+C in Tilt terminal or:
script/tilt-down.sh
```

### Debugging Issues
```bash
# Check Tilt status
tilt get

# View detailed logs
tilt logs learning-hebrew-app

# Manual rebuild
tilt trigger learning-hebrew-app

# Reset if things break
script/tilt-down.sh
kubectl delete namespace learning-hebrew
script/tilt.sh
```

### Performance Optimization
```bash
# Force image rebuild (if live-update isn't working)
tilt trigger learning-hebrew-app --build

# Monitor resource usage
kubectl top pods -n learning-hebrew

# Check Docker space usage
docker system df
```

## Troubleshooting

### Common Issues

**Tilt won't start**: Ensure minikube context and Docker environment:
```bash
kubectl config current-context  # Should be "minikube"
eval $(minikube docker-env)
```

**Port conflicts**: Stop existing port-forwards:
```bash
script/stop-port-forward.sh
pkill -f "kubectl.*port-forward"
```

**Live-update not working**: Check file paths in Tiltfile sync rules, or force rebuild:
```bash
tilt trigger learning-hebrew-app --build
```

**Database connection issues**: Verify PostgreSQL is ready:
```bash
kubectl get pods -n learning-hebrew
kubectl logs deployment/postgres -n learning-hebrew
```

### Reset Everything
```bash
script/tilt-down.sh
kubectl delete namespace learning-hebrew
script/dev.sh
script/tilt.sh
```

## Integration Notes

- **Backwards compatible**: All existing scripts and workflows preserved
- **Production safe**: Tilt only operates in minikube context
- **Resource efficient**: Uses existing Docker and K8s configurations
- **Incremental adoption**: Can be used alongside traditional development

The implementation maintains your existing development patterns while providing optional acceleration through Tilt's automation and live-update capabilities.