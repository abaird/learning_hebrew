# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hebrew learning application built with Ruby on Rails 8, featuring a hierarchical vocabulary structure:
- Users create multiple Decks (vocabulary collections)
- Each Deck contains Words (Hebrew vocabulary)
- Each Word has multiple Glosses (translations/definitions)

## Development Commands

### Local Development
```bash
# Start development server with CSS watch
bin/dev

# Start Rails server only
bin/rails server

# Start Rails console
bin/rails console

# Generate new migrations
bin/rails generate migration MigrationName

# Run database migrations
bin/rails db:migrate

# Reset database
bin/rails db:reset
```

### Docker Development
```bash
# Start services (PostgreSQL + Rails app)
docker-compose -f docker-compose.dev.yml up

# Run Rails commands in container
docker-compose -f docker-compose.dev.yml exec web bin/rails console
```

### Kubernetes Deployment

#### Quick Environment Switching
```bash
# Switch to development (minikube) - auto-starts port forwarding
script/dev.sh

# Switch to production (GKE) - stops port forwarding for safety
script/prod.sh
```

#### Production (GKE)
```bash
# Manual context switching (or use script/prod.sh)
kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster

# Deploy to production
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n learning-hebrew
kubectl get ingress -n learning-hebrew

# View logs
kubectl logs -f deployment/learning-hebrew-app -n learning-hebrew

# Check deployment info (includes Git SHA, build number, etc.)
curl https://learning-hebrew.bairdsnet.net/up
```

#### Local Development (minikube)
```bash
# Manual context switching (or use script/dev.sh)
kubectl config use-context minikube

# Set Docker environment for minikube
eval $(minikube docker-env)

# Build local image
docker build -t learning-hebrew:latest .

# Toggle to local images (use script)
./script/toggle-image.sh

# Deploy to minikube (excluding production secrets)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets-local.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/rails-app.yaml
kubectl apply -f k8s/ingress.yaml

# Port forward for local access (or done automatically by script/dev.sh)
kubectl port-forward service/learning-hebrew-service 8080:80 -n learning-hebrew
```

### Testing

#### Local Testing (Minikube)
```bash
# Run all tests in proper test environment (minikube)
script/test.sh

# Run specific test files
script/test.sh spec/requests/decks_spec.rb

# Run with RSpec options
script/test.sh --format documentation

# Manual testing setup (if needed)
kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- \
  env RAILS_ENV=test DATABASE_URL="postgresql://..." bundle exec rspec
```

#### Local Testing (Traditional)
```bash
# Run RSpec test suite (requires local PostgreSQL)
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

**Note**: The `script/test.sh` approach is recommended as it:
- Runs tests in proper `test` environment (not development)
- Uses separate `learning_hebrew_test` database
- Provides test data isolation from development work
- Automatically handles database setup and cleanup

### Code Quality
```bash
# Run Rubocop linter
bundle exec rubocop

# Auto-fix Rubocop issues
bundle exec rubocop -A

# Run Brakeman security scanner
bundle exec brakeman
```

## Helper Scripts

The `script/` directory contains convenience scripts for common development tasks:

### Environment Management
```bash
# Switch to development environment (minikube + auto port-forward)
script/dev.sh

# Switch to production environment (GKE - no auto port-forward for safety)
script/prod.sh
```

### Deployment Tools
```bash
# Open Rails app in browser (auto-starts port forwarding if needed)
script/open.sh

# Start port forwarding manually
script/port-forward.sh [port]  # defaults to 3000

# Stop port forwarding
script/stop-port-forward.sh

# View application logs
script/logs.sh

# Toggle between local/production Docker images in k8s manifests
script/toggle-image.sh
```

### Testing Tools
```bash
# Run tests in minikube test environment (recommended)
script/test.sh

# Run specific test files
script/test.sh spec/requests/decks_spec.rb

# Run tests with RSpec options
script/test.sh --format documentation --color
```

### Git Integration
- **Pre-push hook**: Automatically runs Rubocop before `git push` to prevent CI failures
- **Override**: Use `git push --no-verify` to skip Rubocop check if needed
- **Auto-fix suggestion**: Hook provides `bundle exec rubocop -A` command when violations found

## Architecture

### Database Schema
- **users**: Devise authentication (email, password)
- **decks**: Named collections belonging to users (name, description, user_id)
- **words**: Hebrew vocabulary items (representation, part_of_speech, mnemonic, pronunciation_url, picture_url, deck_id)
- **glosses**: Translation definitions (text, word_id)

### Database Configuration
- **Development**: `learning_hebrew_development` - for local development work
- **Test**: `learning_hebrew_test` - isolated test environment with automatic cleanup
- **Production**: `learning_hebrew_production` - production data with strong security
- **Host Detection**: Automatically uses `localhost` for local development, `db` for containerized environments
- **Environment Variables**: `DATABASE_HOST` and `DATABASE_URL` control connection settings

### Model Relationships
```
User (1) → Decks (many) → Words (many) → Glosses (many)
```

### Key Technologies
- **Rails 8.0** with modern defaults
- **PostgreSQL** database
- **Devise** for authentication
- **Tailwind CSS** for styling
- **Turbo/Stimulus** for frontend interactivity
- **RSpec** for testing
- **Docker** for containerized development

### File Structure
- `app/models/`: ActiveRecord models with validations and associations
- `app/controllers/`: RESTful controllers for decks, words, glosses
- `app/views/`: ERB templates organized by controller
- `db/migrate/`: Database migration files
- `config/routes.rb`: Defines RESTful routes for all resources

## Development Environment

The application supports multiple development approaches:

**Local**: Requires PostgreSQL, Ruby, and Node.js. Uses `bin/dev` to start Rails server and Tailwind CSS watcher.

**Docker**: Complete environment with PostgreSQL container. Database connection configured for container networking (host: `db`).

**Kubernetes**:
- **Production**: Deployed on Google Kubernetes Engine (GKE) with CI/CD via GitHub Actions
- **Local**: minikube for testing Kubernetes configurations locally before production deployment
- **Testing**: Separate test database (`learning_hebrew_test`) with proper environment isolation

## Deployment Architecture

### Production (GKE)
- **Cluster**: `learning-hebrew-cluster` in `us-central1`
- **Registry**: Google Artifact Registry (`us-central1-docker.pkg.dev/learning-hebrew-1758491674/learning-hebrew/learning-hebrew`)
- **Database**: PostgreSQL with persistent volumes
- **SSL**: Managed certificates via Google Cloud Load Balancer
- **CI/CD**: GitHub Actions workflow triggers on main branch push

### Local Testing (minikube)
- **Purpose**: Test Kubernetes configurations and code changes locally
- **Images**: Local Docker images with `imagePullPolicy: Never`
- **Secrets**: Separate local secrets file (gitignored)
- **Access**: Port forwarding for development testing

## Security & Secrets Management

### Google Secret Manager
All production secrets are stored securely in Google Secret Manager:
```bash
# View secrets
gcloud secrets list

# Get secret value
gcloud secrets versions access latest --secret="secret-name"

# Update secret (creates new version)
echo -n "new_value" | gcloud secrets versions add secret-name --data-file=-
```

**Secrets stored:**
- `postgres-user`: Database username
- `postgres-password`: Strong generated database password
- `rails-master-key`: Rails credentials encryption key
- `secret-key-base`: Rails session encryption key

**Security Features:**
- Secrets never stored in git (only placeholders)
- Automatic injection during CI/CD deployment
- Separate local secrets for development (gitignored)
- Free tier usage (4 secrets well within 6/month limit)

### Deployment Diagnostics

Enhanced `/up` health check endpoint provides deployment information:

```bash
# Check health and deployment info
curl https://learning-hebrew.bairdsnet.net/up

# Example response:
{
  "status": "ok",
  "timestamp": "2025-09-27T19:06:22Z",
  "environment": "production",
  "rails_version": "8.0.2.1",
  "ruby_version": "3.3.3",
  "database": {
    "adapter": "PostgreSQL",
    "connected": true
  },
  "deployment": {
    "git_sha": "abc123...",          # Actual commit SHA
    "build_number": "42",            # GitHub Actions run number
    "deployed_at": "2025-09-27T...", # Deployment timestamp
    "image_tag": "abc123..."         # Docker image tag
  }
}
```

**Useful diagnostic commands:**
```bash
# Get current Git SHA in production
curl -s https://learning-hebrew.bairdsnet.net/up | jq .deployment.git_sha

# Check database connectivity
curl -s https://learning-hebrew.bairdsnet.net/up | jq .database.connected

# View environment info
curl -s https://learning-hebrew.bairdsnet.net/up | jq .environment
```

## Authentication

Uses Devise with custom configurations:
- **Root route**: `words#index` (vocabulary listing)
- **Redirects**: Custom `after_sign_in_path_for` and `after_sign_out_path_for`
- **Host authorization**: Configured for both GKE and minikube IP ranges in production environment

## Recent Updates

### Tilt Integration for Fast Development
- **Installed Tilt v0.35.1**: Fast Kubernetes development workflow with live updates
- **Created development Docker image**: `Dockerfile.dev` optimized for development with proper user permissions
- **Implemented live code syncing**: Changes to Ruby files, views, and assets sync without rebuilds
- **Added manual database reset**: `db-reset` resource in Tilt UI for development database management
- **Fixed permission issues**: Container runs as `rails` user with proper write access for live updates
- **Tilt commands**:
  - `script/tilt-start.sh` - Start Tilt with minikube environment setup
  - `script/tilt-down.sh` - Properly stop Tilt services
  - `script/tilt.sh` - Tilt starter with environment checks
- **Live update triggers**:
  - Code changes (`app/`, `lib/`, `spec/`) sync instantly
  - Gemfile changes trigger `bundle install`
  - Asset changes trigger recompilation
  - Critical config changes trigger full rebuilds
- **Manual triggers**: Database reset available in Tilt UI (manual trigger only)

### GitHub Actions CI/CD Improvements
- **Enhanced deployment debugging**: Added comprehensive logging and error handling to GitHub Actions workflow
- **Fixed service account permissions**: GitHub Actions service account now has proper Secret Manager access
- **Added deployment timeouts**: Prevents infinite hangs during deployment rollouts
- **Improved secret management**: Better error handling when retrieving secrets from Google Secret Manager

## Previous Updates

### Security Enhancements
- **Google Secret Manager integration**: All production secrets now stored securely
- **Strong password generation**: Database and encryption keys use cryptographically secure values
- **Git security**: Removed plain-text secrets from version control
- **Automated secret injection**: CI/CD pipeline pulls secrets from Google Secret Manager

### Developer Experience
- **Environment switching scripts**: `script/dev.sh` and `script/prod.sh` for easy context switching
- **Automatic port forwarding**: Development script auto-starts localhost access
- **Pre-push Git hooks**: Rubocop runs automatically before push to prevent CI failures
- **Deployment diagnostics**: Enhanced `/up` endpoint shows Git SHA, build info, and system status
- **Test environment isolation**: `script/test.sh` runs tests in proper test environment with separate database
- **Database configuration**: Smart host detection for local vs containerized environments

### Infrastructure Improvements
- **Dual environment support**: Minikube (development) vs GKE (production) with proper separation
- **Build information tracking**: Git SHA, build numbers, and deployment timestamps in production
- **Local development optimization**: Faster iteration with automatic Docker builds and port forwarding
- **Monitoring readiness**: Health endpoints provide detailed deployment and system information

### Code Changes
- Set root route to words index page
- Added logout functionality with custom redirect
- Updated host authorization for Kubernetes environments
- Enhanced health controller with comprehensive system diagnostics