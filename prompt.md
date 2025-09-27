# Learning Hebrew Rails App - Project Session Summary

## Current Status
This Rails application has been successfully deployed to Google Kubernetes Engine (GKE) with a complete CI/CD pipeline via GitHub Actions. We've also established local development workflows using minikube.

## Architecture Overview
- **Application**: Ruby on Rails app for learning Hebrew vocabulary
- **Database**: PostgreSQL running in Kubernetes
- **Container Registry**: Google Artifact Registry (`us-central1-docker.pkg.dev/learning-hebrew-1758491674/learning-hebrew/learning-hebrew`)
- **Deployment**: Google Kubernetes Engine (GKE)
- **CI/CD**: GitHub Actions workflow
- **Local Development**: minikube with Docker

## Recent Code Changes Made
These changes have been tested locally in minikube but need to be deployed to production:

1. **Routing Changes**: Set root route to `words#index` and implemented custom Devise redirects
2. **Logout Functionality**: Added logout page and `after_sign_out_path_for` redirect
3. **Host Authorization**: Updated `config/environments/production.rb` to allow both GKE and minikube IP ranges:
   ```ruby
   config.hosts << /10\.21\..*/ # GKE pod IP range
   config.hosts << /34\.118\..*/ # GKE service IP range
   config.hosts << /10\.244\..*/ # Minikube pod IP range
   ```

## Key Files and Configurations

### Kubernetes Manifests (`k8s/`)
- `rails-app.yaml`: Main Rails application deployment with PostgreSQL connection
- `postgres.yaml`: PostgreSQL database with persistent storage
- `ingress.yaml`: Load balancer with SSL certificate management
- `secrets.yaml`: Production secrets (base64 encoded)
- `secrets-local.yaml`: Local development secrets (gitignored)
- `configmap.yaml`: Environment configuration

### Development Tools
- `script/toggle-image.sh`: Script to toggle between local and production Docker images in k8s manifests
- `.github/workflows/fly-deploy.yml`: GitHub Actions CI/CD pipeline

### Local Development Setup
- **Context Switching**: Use `kubectl config use-context minikube` vs `kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster`
- **Image Management**: Local images use `imagePullPolicy: Never`, production uses remote registry
- **Port Forwarding**: Access local app via `kubectl port-forward` to test before production deployment

## Deployment Workflow

### Production Deployment (Current Need)
1. Commit recent code changes
2. Push to GitHub to trigger CI/CD pipeline
3. Monitor deployment in GKE
4. Test production application

### Local Development (Established)
1. Switch to minikube context: `kubectl config use-context minikube`
2. Set Docker environment: `eval $(minikube docker-env)`
3. Build local image: `docker build -t learning-hebrew:latest .`
4. Toggle to local images: `./script/toggle-image.sh`
5. Deploy: `kubectl apply -f k8s/` (excluding secrets-local.yaml for production)
6. Port forward: `kubectl port-forward service/learning-hebrew-service 8080:80 -n learning-hebrew`

## Immediate Next Tasks (In Priority Order)

### 1. Deploy Code Changes to Production (IN PROGRESS)
The recent routing and logout functionality changes need to be deployed to production via the GitHub Actions pipeline.

### 2. Phase 6: Setup learning-hebrew.bairdsnet.net Domain with SSL (PENDING)
- Update `k8s/ingress.yaml` to use the domain `learning-hebrew.bairdsnet.net`
- Configure DNS records to point to the GKE load balancer IP
- Update managed certificate configuration
- Verify SSL certificate provisioning

### 3. Phase 7: Enable Local Development with Tilt for Fast Iteration (PENDING)
- Install and configure Tilt for rapid development cycles
- Set up auto-rebuild and redeploy on code changes
- Integrate with existing minikube setup

## Security Considerations
- Production secrets are base64 encoded in `k8s/secrets.yaml`
- Local secrets are in `k8s/secrets-local.yaml` (gitignored)
- Rails master key and database credentials are properly managed
- Host authorization configured for different Kubernetes IP ranges

## Current Application Features
- User authentication via Devise
- Word/vocabulary management with CRUD operations
- Deck organization for vocabulary sets
- Gloss (translation) management
- PostgreSQL backend with persistent storage
- Responsive design with Tailwind CSS

## Troubleshooting Reference

### Common Issues
- **Image Pull Errors**: Use `imagePullPolicy: Never` for local development
- **Database Connection**: Ensure PostgreSQL service is running and DATABASE_URL is correct
- **Host Authorization**: Add appropriate IP ranges to `config.hosts` in production.rb
- **Context Confusion**: Always verify kubectl context with `kubectl config current-context`

### Useful Commands
```bash
# Check current context
kubectl config current-context

# Switch contexts
kubectl config use-context minikube
kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster

# Check pod status
kubectl get pods -n learning-hebrew

# Port forward for local access
kubectl port-forward service/learning-hebrew-service 8080:80 -n learning-hebrew

# Toggle between local/production images
./script/toggle-image.sh

# Build and set local Docker environment
eval $(minikube docker-env)
docker build -t learning-hebrew:latest .
```

## Next Session Continuation
The last thing CLAUDE said was:

⏺ Perfect! The push has triggered the GitHub Actions CI/CD pipeline. Let me update the todo list to mark this task as completed and check
   the deployment status:

⏺ The code changes have been successfully pushed to trigger the production deployment via GitHub Actions. The CI/CD pipeline will now:

  1. Run tests and linting (make a custom check to do linting before pushing so the build won't fail because of stupid Rubocop errors)
  2. Build the Docker image
  3. Push to Google Artifact Registry
  4. Deploy to GKE with the latest code including your routing changes and logout functionality

  You can monitor the deployment progress on GitHub Actions or check the production pods directly. Once deployed, your recent changes
  (root route to words#index and logout functionality) will be live in production.

  The next phases are ready to proceed when you're ready:
  - Phase 6: Setup learning-hebrew.bairdsnet.net domain with SSL
  - Phase 7: Enable local development with Tilt for fast iteration