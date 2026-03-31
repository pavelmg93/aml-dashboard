"""@bruin
name: convert_patterns_to_csv
image: python:3.12
depends:
  - ingest_kaggle_small
@bruin"""

import os
import logging
from google.cloud import storage
from shared.gcs_utils import get_gcs_bucket, process_and_upload_patterns

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

BUCKET_NAME = os.environ.get("GCP_BUCKET", "aml_dashboard_pmg_bucket")
DATASET_SIZE = os.environ.get("dataset_size", "Small")

def process_patterns():
    bucket = get_gcs_bucket(BUCKET_NAME)
    
    # Process both High-Risk and Low-Risk files
    for risk in ["HI", "LI"]:
        input_path = f"raw/ibm_aml/{risk}-{DATASET_SIZE}_Patterns.txt"
        output_path = f"processed/ibm-aml/{risk}_{DATASET_SIZE}_patterns_flat.csv"
        
        logging.info(f"Processing {risk} patterns for size: {DATASET_SIZE}")
        process_and_upload_patterns(bucket, input_path, output_path)

if __name__ == "__main__":
    process_patterns()