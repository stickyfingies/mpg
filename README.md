# Multiplayer Web Game

A web-based multiplayer game with a Node.js WebSocket server.

## Quick Start

This project is developed on Arch Linux and I don't care about Windows or MacOS.

### Development

1. **Optional:** Generate self-signed SSL certificates for testing local HTTPS traffic.  Beware, cuz the browser will complain.
   ```sh
   make certs
   ```

2. Launch the development server, which auto-magically updates the running app when you change any code:
   ```sh
   make dev
   ```

### Deployment

#### Local Docker Deployment

This project uses [Docker](https://wiki.archlinux.org/title/Docker) to package, ship, and run the web application.

To build the Docker image locally:
```sh
make build-docker
make run-docker
```

#### Google Cloud Deployment with Managed HTTPS

The project uses Terraform to provision and manage Google Cloud Platform infrastructure with secure HTTPS support using Google-managed SSL certificates:

1. Install prerequisites:
   - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
   - [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - A domain name you control (for SSL certificates)

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

5. Deploy to GKE with HTTPS:
   ```
   make deploy-gke
   ```
   
   When prompted, you can:
   - Choose Option 1 to use an automatic domain with nip.io (e.g., `203.0.113.1.nip.io`)
   - Choose Option 2 to enter your own domain name (e.g., `game.example.com`)
   
   **Note**: Do not use `sudo` with the deployment commands. If you're getting Docker permission issues, add your user to the docker group instead:
   ```
   sudo usermod -aG docker $USER
   # Then log out and back in
   ```

6. DNS Configuration (only if using your own domain):
   - Create an A record in your domain's DNS settings pointing to the static IP provided during deployment
   - Google-managed certificates will be automatically provisioned (this takes 15-60 minutes after DNS propagation)
   
   If using nip.io:
   - No DNS configuration is required
   - Certificate provisioning should start automatically
   
7. Check certificate status:
   ```
   kubectl describe managedcertificate web-game-certificate
   ```

8. Re-deploy to GKE:
   ```
   kubectl rollout restart deployment/web-game
   ```

This will deploy your game to a single-instance GKE cluster to ensure all clients connect to the same server.

### Infrastructure Architecture

- Google Kubernetes Engine (GKE) cluster with a single replica for the game server
- Google Artifact Registry for storing Docker images
- Cloud Build for CI/CD
- Ingress controller with Google-managed SSL certificates for HTTPS
- Global static IP address for consistent domain configuration
- Terraform for Infrastructure as Code
- Kustomize for Kubernetes manifest management

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

2. **Certificate fails to provision**: 
   - For custom domains: Ensure the domain is registered and DNS is properly configured. Google-managed certificates require proper DNS configuration to validate domain ownership.
   - For nip.io domains: Try redeploying with a different static IP if there are issues with the current one.

3. **Mixed content warnings**: If your site loads over HTTPS but shows mixed content warnings, make sure your client code is using secure WebSocket connections (wss:// instead of ws://) when the page is loaded over HTTPS.