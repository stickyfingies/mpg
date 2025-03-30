.PHONY: build build-docker deploy-gke terraform-init terraform-plan terraform-apply terraform-destroy

build:
	sh build.sh

build-docker: build
	docker build -t web-game .

deploy-gke: build-docker
	sh deploy-to-gke.sh

terraform-init:
	cd terraform && terraform init

terraform-plan: terraform-init
	cd terraform && terraform plan

terraform-apply: terraform-init
	cd terraform && terraform apply

terraform-destroy: terraform-init
	cd terraform && terraform destroy

# Help target
help:
	@echo "Available targets:"
	@echo "  build            - Build the application"
	@echo "  build-docker     - Build the application and Docker image"
	@echo "  deploy-gke       - Deploy the application to GKE"
	@echo "  terraform-init   - Initialize Terraform"
	@echo "  terraform-plan   - Plan Terraform changes"
	@echo "  terraform-apply  - Apply Terraform changes"
	@echo "  terraform-destroy- Destroy Terraform resources"
	@echo "  help             - Show this help message"

# Default target
.DEFAULT_GOAL := help