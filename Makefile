# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
    include .env
    export
endif

# Force Make to look in the local user bin folders for freshly installed tools
export PATH := $(HOME)/.local/bin:$(HOME)/.cargo/bin:$(PATH)

.PHONY: setup venv infra pipeline clean

# 1. Initial tool installation and GCP linkage
setup:
	chmod +x scripts/setup.sh
	./scripts/setup.sh

# 2. Virtual Environment setup using uv
venv:
	@echo "[/] Setting up virtual environment..."
	uv venv
	./.venv/bin/uv pip install -r requirements.txt
	@echo "[v] Virtual environment ready!"

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
	@echo "[>] Run 'make clean' to delete data and destroy infrastructure."

# 5. Resource cleanup
clean:
	@echo "[!] Destroying GCP Infrastructure..."
	cd terraform && terraform destroy -auto-approve
	@echo "[v] Infrastructure destroyed."

# 6. View the Dashboard
dashboard:
	@echo "[/] Launching AML Dashboard..."
	@echo "Live Dashboard Link:"
	@echo "https://datastudio.google.com/reporting/78f521cd-3007-4151-9cd3-fe4a107d4e8c/page/VdnvF"
	@echo "Hold Cmd/Ctrl and click the link above to view the dashboard."