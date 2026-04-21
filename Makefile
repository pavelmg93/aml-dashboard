# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
    include .env
    export
endif

# Force Make to look in the local user bin folders for freshly installed tools
export PATH := $(HOME)/.local/bin:$(HOME)/.cargo/bin:$(PATH)

.PHONY: setup venv infra pipeline clean dashboard dc-build dc-up dc-setup dc-infra dc-pipeline dc-dashboard dc-down dc-clean

# --- Local Development Targets ---

# 1. Combined Setup: Installs tools and triggers venv automatically
setup:
	chmod +x scripts/setup.sh
	./scripts/setup.sh
	$(MAKE) venv

# 2. Virtual Environment setup using uv
# Switched to pyproject.toml as the source of truth for dependencies
venv:
	@echo "[/] Setting up virtual environment..."
	uv venv --clear
	uv pip install -r pyproject.toml
	@echo "[v] Virtual environment ready!"
	@echo "[>] Run 'make infra' next to provision your GCP resources."

# 3. Infrastructure provisioning
infra:
	@echo "[/] Provisioning GCP Infrastructure with Terraform..."
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "[v] Infrastructure successfully provisioned!"
	@echo "[>] Run 'make pipeline' next to execute the data transformations."

# 4. The full data journey (Ingest -> Stage -> Gold)
pipeline:
	@echo "[/] Running AML Pipeline for dataset: $(BQ_DATASET)..."
	bruin run bruin-pipeline1
	@echo "[v] Pipeline execution complete!"
	@echo "[>] Run 'make dashboard' to see the results."

# 5. View the Dashboard
dashboard:
	@echo "[/] Launching AML Dashboard..."
	@echo "Live Dashboard Link:"
	@echo "https://datastudio.google.com/reporting/78f521cd-3007-4151-9cd3-fe4a107d4e8c/page/VdnvF"
	@echo "Hold Cmd/Ctrl and click the link above to view the dashboard."
	@echo "[>] Run 'make clean' to delete data and destroy infrastructure."

# 6. Resource cleanup
clean:
	@echo "[!] Destroying GCP Infrastructure..."
	cd terraform && terraform destroy -auto-approve
	@echo "[v] Infrastructure destroyed."


# --- Docker Compose Automation Targets ---

# Project Constants
IMAGE_NAME = aml-dashboard-runner

# 1. Build the runner image
dc-build:
	@echo "[/] Building Docker images..."
	docker compose build
	@echo "[v] Build complete."
	@echo "[>] Run 'make dc-setup' to configure your environment, if needed."

# 2. Interactive setup inside container (Shared volume updates .env on host)
dc-setup:
	@echo "[/] Starting interactive setup inside container..."
	docker compose run --rm aml-runner make setup
	@echo "[v] Setup complete."
	@echo "[>] Run 'make dc-up' to start the background runner."

# 3. Start the background runner
dc-up:
	@echo "[/] Starting background services..."
	docker compose up -d
	@echo "[v] Services are up!"
	@echo "[>] Run 'make dc-infra' to provision cloud resources, if needed."
	@echo "[>] Run 'make dc-pipeline' to execute the transformations."


# 4. Provision infra via the runner
dc-infra:
	@echo "[/] Provisioning GCP Infrastructure via Docker..."
	docker compose exec aml-runner make infra
	@echo "[v] Google Cloud infrastructure provisioned!"
	@echo "[>] Run 'make dc-pipeline' to execute the transformations."

# 5. Run the pipeline via the runner
dc-pipeline:
	@echo "[/] Running AML Pipeline inside container..."
	docker compose exec aml-runner make pipeline
	@echo "[v] Containerized pipeline execution complete!"
	@echo "[>] Run 'make dc-dashboard' to get the link."

# 6. Get the dashboard link from the client
dc-dashboard:
	@echo "[/] Fetching Dashboard link from client..."
	docker compose exec aml-client make dashboard
	@echo "[>] Run 'make dc-down' to stop containers."
	@echo "[>] Run 'make dc-clean' for a full purge of Docker and infra."

# 7. Shutdown and remove volumes
dc-down:
	@echo "[/] Shutting down and cleaning up volumes..."
	docker compose down -v
	@echo "[v] Docker services stopped."
	@echo "[>] Run 'make dc-up' to restart services."
	@echo "[>] Run 'make dc-clean' for a full purge of Docker and infra."

# 8. Deep clean: Cloud + Docker
dc-clean:
	@echo "[!] Starting Deep Clean: Cloud + Docker..."
	-docker compose exec aml-runner make clean
	docker compose down -v --rmi all --remove-orphans
	@echo "[v] Cloud resources destroyed and Docker environment purged."

# 9. Daisy-chain all commands with skip logic
dc-go:
	@$(MAKE) dc-up
	@echo ""
	@read -p "[?] Run setup? (y/n): " choice; \
	if [ "$$choice" = "y" ]; then $(MAKE) dc-setup; fi
	@echo ""
	@read -p "[?] Run infra (Terraform)? (y/n): " choice; \
	if [ "$$choice" = "y" ]; then $(MAKE) dc-infra; fi
	@echo ""
	@$(MAKE) dc-pipeline
	@echo ""
	@$(MAKE) dc-dashboard
	@echo ""
	@echo "[v] Full daisy-chain complete. Containers are still running in background."
	@echo "[>] Run 'make dc-down' to stop or 'make dc-clean' to purge."