# aml-dashboard
Anti Money Laundering (AML) Dashboard for Compliance Officers, based on IBM synthetic dataset.

# AML Dashboard: Forensic Narrative & Network Flow (WIP)

## 1. Project Overview
This project transforms the IBM AML synthetic dataset into a **"Walkable Graph"** of illicit money flows using an **11-field deterministic hashing strategy**. 

> **Current Status:** Migration phase. Infrastructure and Staging are handled via Terraform and Bruin. Docker, dlt, and dbt integrations are planned for the next phase.

---

## 2. Installation & Prerequisites

To run this project locally, you need to install the following core tools.

### **A. uv (Fast Python Package Manager)**
Used for managing the Python environment and dependencies.
```bash
curl -LsSf [https://astral.sh/uv/install.sh](https://astral.sh/uv/install.sh) | sh
```

### **B. Terraform (Infrastructure as Code)**
Used to provision GCS buckets and BigQuery datasets.
```bash
wget -O- [https://apt.releases.hashicorp.com/gpg](https://apt.releases.hashicorp.com/gpg) | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] [https://apt.releases.hashicorp.com](https://apt.releases.hashicorp.com) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### **C. Bruin CLI (Orchestration)**
The core engine for running SQL transformations and managing asset dependencies.
```bash
curl -LsSf [https://getbruin.com/install/cli](https://getbruin.com/install/cli) | sh
```

---

## 3. Automation: One-Click Setup
You can automate the entire tool installation process using the provided setup script:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

---

## 4. Environment Configuration (`.env`)

Create a `.env` file in the project root with the following variables:

```bash
# Google Cloud Authentication
export GOOGLE_APPLICATION_CREDENTIALS="/home/<user>/<projects>/aml-dashboard/keys/aml-dash-8888-xxxxxxxxxxxx.json"
export BRUIN_GCP_KEY="./keys/aml-dash-8888-xxxxxxxxxxxx.json"

# Project Resources
export GCP_PROJECT_ID="aml-dash-8888"
export GCP_BUCKET="aml_<user>_bucket"
export BQ_DATASET="aml_bq"

# Data Ingestion
export KAGGLE_API_TOKEN='{"username":"your_user","key":"your_key"}'
```

### **Understanding the Pathing Strategy**
* **GOOGLE_APPLICATION_CREDENTIALS (Absolute Path):** This is required by the Google Cloud SDK and Python client libraries. Since these libraries are system-wide, they require a fixed, absolute path to find your key regardless of which directory your script is running from.
* **BRUIN_GCP_KEY (Relative Path):** This is used specifically by the Bruin CLI. Bruin is a project-aware tool that executes relative to your project root. Using a relative path keeps the project portable across different developer machines.

---

## 5. Execution Flow
1.  **Infrastructure:** `cd terraform && terraform apply`
2.  **Staging:** `bruin run aml_bq.stg_small_trans`
3.  **Gold:** `bruin run aml_bq.fact_transactions`

---

## 6. Future Roadmap
* **Dockerization:** Containerizing the entire environment for one-click deployment.
* **dlt Integration:** Automating the raw data ingestion from Kaggle.
* **dbt Transition:** Exploring dbt for complex modeling beyond Bruin's current scope.
* **Streaming:** Real-time simulation with Red Panda (Kafka).