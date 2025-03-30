# Multiplayer Web Game

A web-based multiplayer game with a Node.js WebSocket server.

## Quick Start

### Development

1. Build all packages:
   ```
   make build
   ```

2. Run client in development mode:
   ```
   cd client
   npm run dev
   ```

3. Run server in development mode:
   ```
   cd server
   npm run dev
   ```

### Deployment

#### Local Docker Deployment

To build the Docker image locally:
```
make build-docker
docker run -p 8080:8080 web-game
```

#### Google Cloud Deployment

The project uses Terraform to provision and manage Google Cloud Platform infrastructure:

1. Install prerequisites:
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
   - [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)

2. Authenticate with Google Cloud:
   ```
   gcloud auth login
   gcloud auth application-default login
   ```

3. Initialize Terraform:
   ```
   make terraform-init
   ```

4. Apply Terraform configuration:
   ```
   make terraform-apply
   ```

5. Deploy to GKE:
   ```
   make deploy-gke
   ```
   
   **Note**: Do not use `sudo` with the deployment commands. If you're getting Docker permission issues, add your user to the docker group instead:
   ```
   sudo usermod -aG docker $USER
   # Then log out and back in
   ```

6. Re-deploy to GKE:
   ```
   kubectl rollout restart deployment/web-game
   ```

This will deploy your game to a single-instance GKE cluster to ensure all clients connect to the same server.

### Infrastructure Architecture

- Google Kubernetes Engine (GKE) cluster with a single replica for the game server
- Google Artifact Registry for storing Docker images
- Cloud Build for CI/CD
- LoadBalancer service to expose the game server
- Terraform for Infrastructure as Code

### CI/CD Pipeline

Pushing to the `master` branch triggers an automatic build and deployment via Cloud Build.

The CI/CD pipeline:
1. Builds the common, client, and server packages
2. Creates a Docker image
3. Pushes the image to Artifact Registry
4. Updates the GKE deployment with the new image

## Directory Structure

- `/client` - Frontend web client
- `/server` - Backend WebSocket server
- `/common` - Shared code between client and server
- `/terraform` - Infrastructure as Code files
- `/k8s` - Kubernetes manifest files

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

5. **External IP not available**: Confirm LoadBalancer service is provisioned correctly:
   ```
   kubectl get service web-game
   ```