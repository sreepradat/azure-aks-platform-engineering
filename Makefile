.DEFAULT_GOAL := help
.PHONY: help install lint test run docker-build docker-run tf-fmt tf-validate helm-lint check

APP_DIR := app
TF_DIR  := terraform/environments/dev
IMAGE   ?= sample-app:local

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-14s %s\n", $$1, $$2}'

install: ## Install app + dev dependencies into the active virtualenv
	pip install -r $(APP_DIR)/requirements.txt -r $(APP_DIR)/requirements-dev.txt

lint: ## Lint the Python code with ruff
	ruff check $(APP_DIR)

test: ## Run unit tests
	cd $(APP_DIR) && pytest

run: ## Run the app locally on http://localhost:8080
	cd $(APP_DIR) && gunicorn --bind 0.0.0.0:8080 main:app

docker-build: ## Build the container image locally
	docker build -t $(IMAGE) $(APP_DIR)

docker-run: ## Run the container image locally on http://localhost:8080
	docker run --rm -p 8080:8080 $(IMAGE)

tf-fmt: ## Format all Terraform code
	terraform fmt -recursive terraform

tf-validate: ## Validate the dev environment (no backend, no Azure access needed)
	terraform -chdir=$(TF_DIR) init -backend=false -input=false
	terraform -chdir=$(TF_DIR) validate

helm-lint: ## Lint and render the Helm chart
	helm lint helm/sample-app
	helm template sample-app helm/sample-app > /dev/null
	helm template sample-app helm/sample-app \
		--set workloadIdentity.enabled=true \
		--set workloadIdentity.clientId=00000000-0000-0000-0000-000000000000 \
		--set workloadIdentity.tenantId=00000000-0000-0000-0000-000000000000 \
		--set workloadIdentity.keyVaultName=kv-example > /dev/null

check: lint test tf-validate helm-lint ## Run every local check
