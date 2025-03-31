#!/bin/bash

###
# This script deploys the containerized application to GKE with HTTPS.
###

set -euo pipefail

echo "🔑 Checking Google Cloud authentication..."

# Check if user is authenticated with gcloud
if ! gcloud auth print-access-token &>/dev/null; then
  echo "⚠️ You are not authenticated with Google Cloud. Please login first."
  echo "Running: gcloud auth login"
  gcloud auth login
fi

# Check if application default credentials exist
if ! gcloud auth application-default print-access-token &>/dev/null; then
  echo "⚠️ Application Default Credentials not found. Setting them up..."
  echo "Running: gcloud auth application-default login"
  gcloud auth application-default login
fi

# Load environment variables from terraform.tfvars if it exists
if [ -f terraform/terraform.tfvars ]; then
  echo "📄 Loading settings from terraform.tfvars..."
  export $(grep -v '^#' terraform/terraform.tfvars | sed 's/\"//g' | sed 's/ //g' | sed 's/\(.*\)=\(.*\)/\1=\2/g')
fi

# If environment variables not set from tfvars, ask for them
if [ -z "${project_id:-}" ]; then
  read -p "Enter your GCP Project ID: " project_id
fi

if [ -z "${region:-}" ]; then
  read -p "Enter GCP Region (default: us-central1): " region
  region=${region:-us-central1}
fi

if [ -z "${_REPOSITORY:-}" ]; then
  _REPOSITORY="web-game"
fi

# Set the active GCP project
echo "🔄 Setting active GCP project to: ${project_id}"
gcloud config set project ${project_id}

# Check if Artifact Registry repository exists, create it if it doesn't
echo "🔍 Checking if Artifact Registry repository exists..."
if ! gcloud artifacts repositories describe ${_REPOSITORY} --location=${region} &>/dev/null; then
  echo "⚠️ Repository doesn't exist. Creating it..."
  gcloud artifacts repositories create ${_REPOSITORY} \
    --repository-format=docker \
    --location=${region} \
    --description="Web Game Docker repository"
fi

# Tag docker image
DOCKER_IMAGE="${region}-docker.pkg.dev/${project_id}/${_REPOSITORY}/web-game:latest"
echo "🏷️ Tagging Docker image as ${DOCKER_IMAGE}..."
docker tag web-game:latest ${DOCKER_IMAGE}

# Configure Docker to use gcloud credentials
echo "🔒 Configuring Docker to use gcloud credentials..."
gcloud auth configure-docker ${region}-docker.pkg.dev --quiet

# Push to Artifact Registry
echo "⬆️ Pushing Docker image to Artifact Registry..."
docker push ${DOCKER_IMAGE}

# Check if GKE cluster exists
echo "🔍 Checking if GKE cluster exists..."
if ! gcloud container clusters describe web-game-cluster --region=${region} &>/dev/null; then
  echo "⚠️ GKE cluster doesn't exist. Please run 'npm run terraform:apply' first."
  exit 1
fi

# Update the deployment YAML with the correct registry URL
echo "📝 Updating Kubernetes manifest files..."
sed -i "s|REGISTRY_URL|${region}-docker.pkg.dev/${project_id}/${_REPOSITORY}|g" k8s/deployment.yaml

# Get GKE cluster credentials
echo "🔑 Getting GKE cluster credentials..."
gcloud container clusters get-credentials web-game-cluster --region ${region} --project ${project_id}

# Create a static IP address if it doesn't exist
echo "🌐 Setting up static IP address..."
IP_NAME="web-game-ip"
if ! gcloud compute addresses describe $IP_NAME --global &>/dev/null; then
  echo "Creating static IP address..."
  gcloud compute addresses create $IP_NAME --global
fi

# Get the static IP address
STATIC_IP=$(gcloud compute addresses describe $IP_NAME --global --format='get(address)')
echo "🌐 Static IP address: $STATIC_IP"

# Handle domain name - offer automatic nip.io option or custom domain
if [ -z "${domain_name:-}" ]; then
  echo "Select domain option:"
  echo "1) Use automatic nip.io domain ($STATIC_IP.nip.io)"
  echo "2) Enter a custom domain name"
  read -p "Enter your choice (1-2): " domain_choice
  
  case $domain_choice in
    1)
      domain_name="$STATIC_IP.nip.io"
      echo "Using automatic domain: $domain_name"
      ;;
    2)
      read -p "Enter domain name for Google-managed SSL certificate (e.g., game.example.com): " domain_name
      
      # Validate domain name format
      if [[ ! "$domain_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        echo "⚠️ Invalid domain name format. Please provide a valid domain name."
        exit 1
      fi
      ;;
    *)
      echo "Invalid choice. Using automatic nip.io domain."
      domain_name="$STATIC_IP.nip.io"
      ;;
  esac
fi

# Prepare managed certificate with domain name
echo "🔒 Setting up Google-managed SSL certificate..."
sed "s/\${DOMAIN_NAME}/${domain_name}/g" k8s/managed-certificate.yaml > k8s/managed-certificate-filled.yaml

# Apply Kubernetes manifests
echo "🚀 Applying Kubernetes manifests..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/managed-certificate-filled.yaml
kubectl apply -f k8s/ingress.yaml

# Wait a moment for resources to be created
sleep 3

# DNS configuration message based on domain type
if [[ "$domain_name" == *".nip.io" ]]; then
  echo "🔄 Using nip.io domain: ${domain_name}"
  echo "No DNS configuration needed - nip.io automatically resolves to your IP address"
else
  echo "🔄 DNS Configuration Reminder:"
  echo "You need to create an A record for ${domain_name} pointing to ${STATIC_IP}"
fi

# Check the status of the Ingress
echo "⏳ Waiting for Ingress to be ready..."
echo "  (Note: This process can take 5-10 minutes for the Ingress and certificates to be provisioned)"
echo "  (You can continue with DNS configuration while waiting)"

echo "==================================="
echo "🎮 Web Game deployment initiated!"
echo "🌐 Your game will be accessible at: http://${domain_name}"
echo "🔒 Once certificate is provisioned: https://${domain_name}"
echo ""

if [[ "$domain_name" == *".nip.io" ]]; then
  echo "💡 Using automatic nip.io domain:"
  echo "  - No DNS configuration required"
  echo "  - Certificate provisioning should start automatically"
  echo "  - This typically takes 15-30 minutes to become active"
else
  echo "🔄 DNS Configuration Instructions:"
  echo "  1. Log in to your domain registrar"
  echo "  2. Create an A record for ${domain_name} pointing to ${STATIC_IP}"
  echo "  3. Certificate provisioning may take up to 60 minutes after DNS is configured"
fi

echo ""
echo "💡 Check certificate status with:"
echo "  kubectl describe managedcertificate web-game-certificate"
echo "==================================="