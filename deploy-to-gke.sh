#!/bin/bash
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

# Apply Kubernetes manifests
echo "🚀 Applying Kubernetes manifests..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Get the external IP of the service (this may take a minute to provision)
echo "⏳ Waiting for external IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get service web-game -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "⏳ Waiting for external IP..."
    sleep 10
  fi
done

echo "==================================="
echo "🎮 Web Game deployed successfully!"
echo "🌐 Access your game at: http://${EXTERNAL_IP}"
echo "==================================="