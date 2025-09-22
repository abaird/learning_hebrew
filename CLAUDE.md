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

#### Production (GKE)
```bash
# Switch to GKE context
kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster

# Deploy to production
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n learning-hebrew
kubectl get ingress -n learning-hebrew

# View logs
kubectl logs -f deployment/learning-hebrew-app -n learning-hebrew
```

#### Local Development (minikube)
```bash
# Switch to minikube context
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

# Port forward for local access
kubectl port-forward service/learning-hebrew-service 8080:80 -n learning-hebrew
```

### Testing
```bash
# Run RSpec test suite
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

### Code Quality
```bash
# Run Rubocop linter
bundle exec rubocop

# Auto-fix Rubocop issues
bundle exec rubocop -A

# Run Brakeman security scanner
bundle exec brakeman
```

## Architecture

### Database Schema
- **users**: Devise authentication (email, password)
- **decks**: Named collections belonging to users (name, description, user_id)
- **words**: Hebrew vocabulary items (representation, part_of_speech, mnemonic, pronunciation_url, picture_url, deck_id)
- **glosses**: Translation definitions (text, word_id)

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

## Authentication

Uses Devise with custom configurations:
- **Root route**: `words#index` (vocabulary listing)
- **Redirects**: Custom `after_sign_in_path_for` and `after_sign_out_path_for`
- **Host authorization**: Configured for both GKE and minikube IP ranges in production environment

## Recent Updates

### Code Changes
- Set root route to words index page
- Added logout functionality with custom redirect
- Updated host authorization for Kubernetes environments

### Infrastructure
- Established local minikube development workflow
- Created toggle script for switching between local/production images
- Configured separate secrets management for local vs production