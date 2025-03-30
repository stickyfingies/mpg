terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "services" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  
  project = var.project_id
  service = each.key
  disable_on_destroy = false
}

# Artifact Registry repository for storing Docker images
resource "google_artifact_registry_repository" "web_game" {
  location      = var.region
  repository_id = "web-game"
  format        = "DOCKER"
  
  depends_on = [google_project_service.services["artifactregistry.googleapis.com"]]
}

# GKE Cluster
resource "google_container_cluster" "web_game" {
  name     = "web-game-cluster"
  location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to use
  # a separately managed node pool. So we create the smallest possible
  # default node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    # Let GKE choose IP ranges automatically
  }
  
  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  depends_on = [google_project_service.services["container.googleapis.com"]]
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.region
  cluster    = google_container_cluster.web_game.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"
    preemptible  = false

    # Enable Workload Identity on the node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# Cloud Build trigger for continuous deployment
resource "google_cloudbuild_trigger" "web_game" {
  name        = "web-game-trigger"
  description = "Build and deploy web game on new image"
  
  filename = "cloudbuild.yaml"
  
  included_files = ["**"]
  
  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^master$"
    }
  }
  
  depends_on = [google_project_service.services["cloudbuild.googleapis.com"]]
}

# Create a service account for Cloud Build to access GKE
resource "google_service_account" "cloudbuild_gke" {
  account_id   = "cloudbuild-gke"
  display_name = "Cloud Build GKE Service Account"
}

# Allow Cloud Build to access GKE
resource "google_project_iam_member" "cloudbuild_gke" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild_gke.email}"
}

# Outputs
output "kubernetes_cluster_name" {
  value       = google_container_cluster.web_game.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_endpoint" {
  value       = google_container_cluster.web_game.endpoint
  description = "GKE Cluster Host"
}

output "artifact_registry_repository" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.web_game.repository_id}"
  description = "Artifact Registry Repository URL"
}