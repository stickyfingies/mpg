.PHONY: certs dev build docker-build docker-run terraform-init terraform-plan terraform-apply terraform-destroy deploy-gke

# Help target
help:
	@echo "Available targets:"
	@echo "  certs            - Generate SSL certificates"
	@echo "  dev              - Start the development server"
	@echo "  build            - Build the application"
	@echo "  docker-build     - Build the application and Docker image"
	@echo "  docker-run       - Run the application in a Docker container"
	@echo "  terraform-init   - Initialize Terraform"
	@echo "  terraform-plan   - Plan Terraform changes"
	@echo "  terraform-apply  - Apply Terraform changes"
	@echo "  terraform-destroy- Destroy Terraform resources"
	@echo "  deploy-gke       - Deploy the application to GKE with HTTPS"
	@echo "  help             - Show this help message"

# Default target
.DEFAULT_GOAL := help

certs:
	sh make-certs.sh

dev:
	cd server && npm run dev

build:
	sh build.sh

docker-build: build
	docker build -t web-game .

docker-run: docker-build
	docker run -p 8080:8080 web-game

terraform-init:
	cd terraform && terraform init

terraform-plan: terraform-init
	cd terraform && terraform plan

terraform-apply: terraform-init
	cd terraform && terraform apply

terraform-destroy: terraform-init
	cd terraform && terraform destroy

deploy-gke: docker-build terraform-apply
	sh deploy-to-gke.sh