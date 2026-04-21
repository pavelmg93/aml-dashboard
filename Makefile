# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
    include .env
    export
endif

# Force Make to look in the local user bin folders for freshly installed tools
export PATH := $(HOME)/.local/bin:$(HOME)/.cargo/bin:$(PATH)

# Ensure dc-go and ensure-env are in the PHONY list
.PHONY: setup venv infra pipeline clean dashboard dc-build dc-up dc-setup dc-infra dc-pipeline dc-dashboard dc-down dc-clean ensure-env dc-go

# --- Helper Targets ---

# This creates a blank .env so Docker doesn't crash before the setup script runs
ensure-env:
	@if [ ! -f .env ]; then \
		echo "[!] .env not found, creating a temporary one for Docker..."; \
		touch .env; \
	fi

# --- Local Development Targets ---

setup:
	chmod +x scripts/setup.sh
	./scripts/setup.sh
	$(MAKE) venv

venv:
	@echo "[/] Setting up virtual environment..."
	uv venv --clear
	uv pip install -r pyproject.toml
	@echo "[v] Virtual environment ready!"

infra:
	@echo "[/] Provisioning GCP Infrastructure with Terraform..."
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "[v] Infrastructure successfully provisioned!"

pipeline:
	@echo "[/] Running AML Pipeline for dataset: $(BQ_DATASET)..."
	bruin run bruin-pipeline1
	@echo "[v] Pipeline execution complete!"

dashboard:
	@echo ""
	@echo "============================================================"
	@echo "           AML DASHBOARD SETUP INSTRUCTIONS             "
	@echo "============================================================"
	@echo "[/] 1. OPEN TEMPLATE:"
	@echo "    https://datastudio.google.com/reporting/78f521cd-3007-4151-9cd3-fe4a107d4e8c/page/VdnvF"
	@echo ""
	@echo "[/] 2. COPY THE REPORT:"
	@echo "    Click the (⋮) menu in the top right -> Select 'Make a copy'."
	@echo ""
	@echo "[/] 3. CONNECT YOUR BIGQUERY DATA:"
	@echo "    In the 'New Data Source' dropdown, select 'Create data source'."
	@echo "    Choose 'BigQuery' -> Select your Project -> $(BQ_DATASET) -> 'all_transactions'."
	@echo "    Click 'Connect' -> 'Add to Report' -> 'Copy Report'."
	@echo "============================================================"
	@echo "[v] Dashboard is now wired to your specific GCP environment."
	@echo "[>] Run 'make clean' to delete data and destroy infrastructure."

clean:
	@echo "[!] Destroying GCP Infrastructure..."
	cd terraform && terraform destroy -auto-approve
	@echo "[v] Infrastructure destroyed."


# --- Docker Compose Automation Targets ---

dc-build:
	@echo "[/] Building Docker images..."
	docker compose build
	@echo "[v] Build complete."

# Added ensure-env as a dependency
dc-setup: ensure-env
	@echo "[/] Starting interactive setup inside container..."
	docker compose run --rm aml-runner make setup
	@echo "[v] Setup complete."

# Added ensure-env as a dependency
dc-up: ensure-env
	@echo "[/] Starting background services..."
	docker compose up -d
	@echo "[v] Services are up!"

dc-infra:
	@echo "[/] Provisioning GCP Infrastructure via Docker..."
	docker compose exec aml-runner make infra

dc-pipeline:
	@echo "[/] Running AML Pipeline inside container..."
	docker compose exec aml-runner make pipeline

dc-dashboard:
	@echo "[/] Fetching Dashboard instructions from client..."
	@docker compose exec aml-client make dashboard
	@echo ""
	@echo "[>] Run 'make dc-down' to stop containers."
	@echo "[>] Run 'make dc-clean' for a full purge of Docker and infra."

# The Ultimate Command
dc-go:
	@$(MAKE) dc-build
	@echo ""
	@read -p "[?] Run interactive setup? (y/n): " choice; \
	if [ "$$choice" = "y" ]; then $(MAKE) dc-setup; fi
	@echo ""
	@$(MAKE) dc-up
	@echo ""
	@read -p "[?] Provision Cloud Infrastructure (Terraform)? (y/n): " choice; \
	if [ "$$choice" = "y" ]; then $(MAKE) dc-infra; fi
	@echo ""
	@$(MAKE) dc-pipeline
	@echo ""
	@$(MAKE) dc-dashboard
	@echo ""
	@echo "[v] Full daisy-chain complete. Containers are still running in background."

dc-down:
	@echo "[/] Shutting down and cleaning up volumes..."
	docker compose down -v

dc-clean:
	@echo "[!] Starting Deep Clean: Cloud + Docker..."
	-docker compose exec aml-runner make clean
	docker compose down -v --rmi all --remove-orphans
	@echo "[v] Environment purged."