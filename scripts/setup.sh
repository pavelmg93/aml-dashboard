#!/bin/bash

echo "[/] Starting AML Dashboard Setup..."

# 1. Install uv
if ! command -v uv &> /dev/null; then
    echo "[.] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "[v] uv is already installed."
fi

# 2. Install Terraform
if ! command -v terraform &> /dev/null; then
    echo "[.] Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
else
    echo "[v] Terraform is already installed."
fi

# 3. Install Bruin
if ! command -v bruin &> /dev/null; then
    echo "[.] Installing Bruin CLI..."
    curl -LsSf https://getbruin.com/install/cli | sh
else
    echo "[v] Bruin is already installed."
fi

echo "[v] All core tools installed!"

# 4. JSON Key Discovery
echo ""
echo "============================================================"
echo "[!] ACTION REQUIRED: Google Cloud Service Account Key"
echo "Please ensure your downloaded Service Account .json"
echo "key file is placed in the 'keys/' folder."
echo "============================================================"
mkdir -p keys
read -n 1 -s -r -p "Press any key when the file is ready..."
echo ""

KEY_FILE=$(ls -1 keys/*.json 2>/dev/null | head -n 1)

if [ -z "$KEY_FILE" ]; then
    echo "[!] Error: No .json file found in 'keys/'. Please add it and try again."
    exit 1
fi

KEY_NAME=$(basename "$KEY_FILE")
REL_PATH="./keys/$KEY_NAME"
ABS_PATH="$(pwd)/keys/$KEY_NAME"

echo "[v] Found key: $KEY_NAME"

# 5. Interactive .env Generation
if [ -f .env ]; then
    read -p "[!] A .env file already exists. Overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting setup. Please manually check your .env file."
        exit 1
    fi
fi

echo "[/] Configuring environment variables..."

read -p "Enter your GCP Project ID (e.g., aml-dash-8888): " PROJECT_ID
read -p "Enter your GCS Bucket Name (e.g., aml-pmg-bucket): " BUCKET
read -p "Enter your BQ Dataset Name (e.g., aml_bq): " DATASET
read -p "Enter your Kaggle API Token (JSON string): " KAGGLE_TOKEN

cat <<EOF > .env
export GOOGLE_APPLICATION_CREDENTIALS=$ABS_PATH
export BRUIN_GCP_KEY=$REL_PATH
export GCP_PROJECT_ID=$PROJECT_ID
export GCP_BUCKET=$BUCKET
export BQ_DATASET=$DATASET
export KAGGLE_API_TOKEN=$KAGGLE_TOKEN
EOF

echo "[v] .env file created successfully!"

# 6. Dynamically Update Terraform Variables
echo "[/] Syncing Terraform variables..."

# Ensure the terraform directory exists just in case
mkdir -p terraform

# Check for existing variables.tf and back it up
if [ -f terraform/variables.tf ]; then
    BACKUP_NAME="terraform/variables.tf.bak_$(date +%Y%m%d_%H%M%S)"
    echo "[!] Existing variables.tf found. Backing up to $BACKUP_NAME"
    mv terraform/variables.tf "$BACKUP_NAME"
fi

cat <<EOF > terraform/variables.tf
variable "project" {
  description = "AML Dashboard Project ID"
  default     = "$PROJECT_ID"
}

variable "region" {
  description = "Region"
  default     = "us-central1"
}

variable "location" {
  description = "Project Location"
  default     = "us-central1"
}

variable "bq_dataset_name" {
  description = "AML Dashboard BigQuery Dataset"
  default     = "$DATASET"
}

variable "gcs_bucket_name" {
  description = "AML Storage Bucket Name"
  default     = "$BUCKET"
}

variable "gcs_storage_class" {
  description = "Bucket Storage Class"
  default     = "STANDARD"
}
EOF

echo "[v] terraform/variables.tf updated!"

# 7. Dynamically Update Bruin Pipeline Variables
echo "[/] Syncing Bruin pipeline variables..."

# Check for existing pipeline.yml and back it up
if [ -f bruin-pipeline1/pipeline.yml ]; then
    BACKUP_NAME="bruin-pipeline1/pipeline.yml.bak_$(date +%Y%m%d_%H%M%S)"
    echo "[!] Existing pipeline.yml found. Backing up to $BACKUP_NAME"
    mv bruin-pipeline1/pipeline.yml "$BACKUP_NAME"
fi

cat <<EOF > bruin-pipeline1/pipeline.yml
name: bruin-init
schedule: daily
start_date: "2026-03-31"
catchup: false

default_connections:
  google_cloud_platform: "gcp_conn"

variables:
  GCP_PROJECT_ID:
    type: string
    default: "$PROJECT_ID"
  BQ_DATASET:
    type: string
    default: "$DATASET"
  GCP_BUCKET:
    type: string
    default: "$BUCKET"
  DATASET_SIZE:
    type: string
    default: "small"
EOF

echo "[v] bruin-pipeline1/pipeline.yml updated!"

echo "[/] Hardcoding dataset names into Bruin headers for validation..."

# Prepend the dataset name to 'name:' and 'depends:' fields
# This uses $DATASET to match the variable used in your pipeline.yml
find bruin-pipeline1/assets -name "*.sql" -exec sed -i "s/name: /name: $DATASET./g" {} +
find bruin-pipeline1/assets -name "*.sql" -exec sed -i "s/- / - $DATASET./g" {} +

# Clean up any double-prepends if script is run multiple times
find bruin-pipeline1/assets -name "*.sql" -exec sed -i "s/$DATASET\.$DATASET\./$DATASET\./g" {} +

echo "[v] Bruin headers synchronized with BigQuery!"