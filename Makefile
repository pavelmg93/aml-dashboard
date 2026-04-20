# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
    include .env
    export
endif

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