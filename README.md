# Multiplayer Web Game

**What is it?** A web-based multiplayer game deployed on GKE based on Node.js, WebGL2, and WebSockets.

**Why make this?** to practice building and deploying real-time distributed systems.

The README is partially a description of the project itself, and partially a tutorial to make it run on your own GCP infrastructure.

## Quick Start

I made the project on Arch Linux btw and haven't tested these instructions on other Linux distributions.

The project uses [Make](https://en.wikipedia.org/wiki/Make_(software)) as the primary interface for build and deployment automation.

### Development

1. **Optional - not required:** Generate self-signed SSL certificates and keys for the development server:
   ```sh
   make certs
   ```

2. Build the project's front-end and back-end applications:
   ```sh
   make build
   ```

3. Start the Vite development server for real-time updates:
   ```sh
   make dev
   ```

### Deployment

#### Local Docker Deployment

Make sure you have [Docker](https://wiki.archlinux.org/title/Docker) installed and the Daemon is running.

Build the application's Docker image and run it locally:
```sh
make docker-build
make docker-run
```

**Note**: Don't be an idiot like me and use `sudo` with docker commands. If you're getting Docker permission issues just add your user to the docker group instead:
```sh
sudo usermod -aG docker $USER
# Then log out and back in
```

#### Google Cloud Deployment

Your machine must have [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install), and [kubectl](https://kubernetes.io/docs/tasks/tools/) installed to properly deploy the application onto GKE.

1. Replace the values in `terraform/terraform.tfvars` to match your GCP project name and GitHub username/repo, since you obviously can't use mine.

2. Authenticate with Google Cloud:
   ```sh
   gcloud auth login
   gcloud auth application-default login
   ```

3. Build the Terraform and deploy to GKE:
   ```sh
   make deploy-gke
   ```
   
4. Check certificate status:
   ```sh
   # Will be 'Provisioning' for 15-60 minutes until 'Active'
   kubectl describe managedcertificate web-game-certificate
   ```

## Infrastructure Architecture

- Google Kubernetes Engine (GKE) cluster with a single replica for the game server
- Google Artifact Registry for storing Docker images
- Cloud Build for CI/CD (broken atm)
- Ingress controller with Google-managed SSL certificates for HTTPS
- Global static IP address for consistent domain configuration
- Terraform for Infrastructure as Code

## Directory Structure

- `/client` - Frontend web client
- `/server` - Backend WebSocket server
- `/common` - Shared code between client and server
- `/terraform` - Infrastructure as Code files
- `/k8s` - Kubernetes manifest files
- `/certificates` - Local SSL certificates (.gitignore'd)

## Troubleshooting

### Authentication Issues

If you see errors like `Unauthenticated request` or `Permission denied`:

1. Make sure you're authenticated with Google Cloud:
   ```
   gcloud auth login
   gcloud auth application-default login
   ```

2. Check if you have the necessary permissions in your GCP project:
   - Artifact Registry Administrator
   - Kubernetes Engine Admin
   - Service Account User
   - Compute Network Admin (for managed certificates)

3. Verify the correct project is selected:
   ```
   gcloud config set project YOUR_PROJECT_ID
   ```

### Deployment Issues

1. **GKE cluster doesn't exist**: Run `make terraform-apply` to create the infrastructure.

2. **Docker build fails**: Check if Docker daemon is running with `docker ps`.

3. **Image push fails**: Verify Artifact Registry is enabled and you have proper permissions:
   ```
   gcloud services enable artifactregistry.googleapis.com
   ```

4. **Kubernetes deployment fails**: Check GKE cluster status:
   ```
   gcloud container clusters list
   kubectl get nodes
   ```

5. **Ingress not available**: Check Ingress and certificate status:
   ```
   kubectl get ingress web-game-ingress
   kubectl get managedcertificate web-game-certificate
   ```

### SSL Certificate Issues

1. **Certificate stuck in provisioning**:
   
   For custom domains, verify DNS is properly configured:
   ```
   # Get your static IP
   gcloud compute addresses describe web-game-ip --global
   
   # Then verify your domain's A record points to this IP
   # You can use nslookup to check:
   nslookup YOUR_DOMAIN_NAME
   ```
   
   For nip.io domains:
   ```
   # Verify nip.io is resolving correctly
   nslookup YOUR_IP.nip.io
   
   # Check certificate status
   kubectl describe managedcertificate web-game-certificate
   ```