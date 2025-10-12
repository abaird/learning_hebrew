# Tiltfile for Learning Hebrew App
# Provides fast local development with minikube

# Import Tilt constants
load('ext://namespace', 'namespace_yaml')

# Ensure we're in minikube context for safety
expected_context = 'minikube'
actual_context = str(local('kubectl config current-context')).strip()
if actual_context != expected_context:
    fail('Expected kubectl context "%s", got "%s". Run script/dev.sh first.' % (expected_context, actual_context))

# Build the development Docker image with live-update capabilities
docker_build(
    'learning-hebrew:local',
    context='.',
    dockerfile='./Dockerfile.dev',

    # Live update configuration for fast Ruby development
    live_update=[
        # Fall back to full rebuild only for dependency changes
        fall_back_on(['./Gemfile', './Gemfile.lock', './package.json', './package-lock.json']),

        # Sync Ruby application code
        sync('./app', '/rails/app'),
        sync('./lib', '/rails/lib'),
        sync('./spec', '/rails/spec'),
        sync('./config', '/rails/config'),
        sync('./db', '/rails/db'),

        # Run commands inside container for certain changes
        run('bundle install', trigger=['./Gemfile', './Gemfile.lock']),
        # Note: Asset precompile removed - Rails 8 Propshaft serves assets directly in development
        # Just syncing the files is enough for live CSS updates
    ],

    # Only rebuild image when Dockerfile or key dependencies change
    ignore=['.git', 'tmp/', 'log/', 'storage/', '.port-forward.pid', 'projects/', 'vocab/']
)

# Apply Kubernetes manifests (use local configurations for minikube)
k8s_yaml([
    'k8s/namespace.yaml',
    'k8s/local/configmap-local.yaml',
    'k8s/local/secrets-local.yaml',
    'k8s/local/postgres-local.yaml',
    'k8s/local/rails-app-local.yaml',
    'k8s/local/ingress-local.yaml',
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
    cmd='kubectl scale deployment/learning-hebrew-app --replicas=0 -n learning-hebrew && ' +
        'kubectl wait --for=delete pod -l app=learning-hebrew-app -n learning-hebrew --timeout=60s && ' +
        'kubectl exec deployment/postgres -n learning-hebrew -- psql -U postgres -c "DROP DATABASE IF EXISTS learning_hebrew_development;" && ' +
        'kubectl exec deployment/postgres -n learning-hebrew -- psql -U postgres -c "CREATE DATABASE learning_hebrew_development;" && ' +
        'kubectl scale deployment/learning-hebrew-app --replicas=1 -n learning-hebrew && ' +
        'kubectl wait --for=condition=ready pod -l app=learning-hebrew-app -n learning-hebrew --timeout=120s && ' +
        'kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- bin/rails db:migrate db:seed',
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
    resource_deps=['postgres'],
    labels=['database', 'manual']
)

print("🚀 Tilt configuration loaded!")
print("📱 Rails app: http://localhost:3000")
print("🗄️  PostgreSQL: localhost:5432")
print("💡 Run 'tilt up' to start development environment")