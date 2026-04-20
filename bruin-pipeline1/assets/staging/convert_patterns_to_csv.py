"""@bruin
name: convert_patterns_to_csv
image: python:3.12
depends:
  - ingest_kaggle_small
@bruin"""

import os
import sys
import logging
from pathlib import Path
from google.cloud import storage

# Calculate the project root (3 levels up from assets/staging/)
# Use .resolve() to handle absolute paths in the Bruin container
root_path = str(Path(__file__).resolve().parent.parent.parent)
if root_path not in sys.path:
    sys.path.append(root_path)
from shared.gcs_utils import get_gcs_bucket, process_and_upload_patterns


logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

BUCKET_NAME = os.environ.get("GCP_BUCKET")
DATASET_SIZE = os.environ.get("DATASET_SIZE", "small")

def process_patterns():
    bucket = get_gcs_bucket(BUCKET_NAME)
    
    raw_size_label = DATASET_SIZE.capitalize() 
    
    for risk in ["HI", "LI"]:
        input_path = f"raw/ibm_aml/{risk}-{raw_size_label}_Patterns.txt"
        output_path = f"processed/ibm-aml/{risk}_{DATASET_SIZE}_patterns_flat.csv"
        
        logging.info(f"Processing {risk} patterns for size: {DATASET_SIZE}")
        
        process_and_upload_patterns(bucket, input_path, output_path)

if __name__ == "__main__":
    try:
        process_patterns()
        logging.info("Process patterns completed successfully.")
    except Exception as e:
        logging.error(f"PIPELINE CRASHED: {e}", exc_info=True)
        sys.exit(1)