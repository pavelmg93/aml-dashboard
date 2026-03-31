"""@bruin
name: ingest_kaggle_small
image: python:3.12
@bruin"""

import os
import logging
from kaggle.api.kaggle_api_extended import KaggleApi
from google.cloud import storage
from google.api_core.exceptions import GoogleAPIError

# Configure basic logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# Configuration constants
DATASET_SLUG = "ealtman2019/ibm-transactions-for-anti-money-laundering-aml"
BUCKET_NAME = "aml_dashboard_pmg_bucket"
TARGET_KEYWORD = "Small"

def main():
    logging.info("Initializing Kaggle and GCS clients...")
    
    try:
        # 1. Authenticate with Kaggle (Automatically picks up KAGGLE_USERNAME/KEY from .env)
        kaggle_api = KaggleApi()
        kaggle_api.authenticate()

        # 2. Authenticate with GCS (Automatically picks up GOOGLE_APPLICATION_CREDENTIALS)
        storage_client = storage.Client()
        bucket = storage_client.bucket(BUCKET_NAME)
    except Exception as e:
        logging.error(f"Failed to initialize API clients: {e}")
        return

    logging.info(f"Fetching file list for dataset: {DATASET_SLUG}")
    
    try:
        # 3. Retrieve dataset metadata and filter for the target keyword
        dataset_files = kaggle_api.dataset_list_files(DATASET_SLUG).files
        target_files = [f for f in dataset_files if TARGET_KEYWORD in f.name]
        
        if not target_files:
            logging.warning(f"No files containing '{TARGET_KEYWORD}' found in the dataset.")
            return
            
        logging.info(f"Found {len(target_files)} file(s) matching '{TARGET_KEYWORD}'.")
    except Exception as e:
        logging.error(f"Failed to fetch dataset file list from Kaggle: {e}")
        return

    # Extract owner and dataset name for the raw API call
    owner_slug, dataset_name = DATASET_SLUG.split('/')

    # 4. Stream each filtered file directly to GCS, indempotently (skip if already exist)
    for file_obj in target_files:
        file_name = file_obj.name
        gcs_destination = f"raw/ibm_aml/{file_name}" # Organizes files into a 'raw' folder
        blob = bucket.blob(gcs_destination)

        # Check if the file already exists to avoid redundant processing
        if blob.exists():
            logging.info(f"⏩ {file_name} already exists in GCS. Skipping.")
            continue

        logging.info(f"Starting stream for {file_name} -> gs://{BUCKET_NAME}/{gcs_destination}")
        
        try:
            # Route the download to the system's temporary directory
            temp_dir = "/tmp"
            kaggle_api.dataset_download_file(DATASET_SLUG, file_name, path=temp_dir)
            
            # Kaggle may append .zip depending on file size/type. We check for both.
            local_path = f"{temp_dir}/{file_name}"
            if not os.path.exists(local_path):
                local_path += ".zip"
                
            logging.info(f"Uploading {local_path} to GCS...")
            
            # Upload the temporarily cached file to GCS
            blob.upload_from_filename(local_path)
            logging.info(f"Successfully uploaded {file_name} to gs://{BUCKET_NAME}/{gcs_destination}")
            
            # Immediately delete the local file to keep disk space free
            if os.path.exists(local_path):
                os.remove(local_path)
            
        except GoogleAPIError as gcp_err:
            logging.error(f"GCS Upload Error for {file_name}: {gcp_err}")
        except Exception as e:
            logging.error(f"Unexpected error processing {file_name}: {e}")

if __name__ == "__main__":
    main()