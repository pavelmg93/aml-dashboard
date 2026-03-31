import io
import csv
import logging
from google.cloud import storage

def get_gcs_bucket(bucket_name):
    client = storage.Client()
    return client.bucket(bucket_name)

def process_and_upload_patterns(bucket, input_path, output_path):
    """
    Shared logic to stream raw pattern TXT, flatten it, 
    and upload CSV back to GCS.
    """
    input_blob = bucket.blob(input_path)
    output_blob = bucket.blob(output_path)

    if not input_blob.exists():
        logging.warning(f"File not found: {input_path}")
        return

    output_buffer = io.StringIO()
    writer = csv.writer(output_buffer)
    
    # Standard AML Header
    header = [
        "Timestamp",
        "From_Bank",
        "Account",
        "To_Bank",
        "Account_4",               
        "Amount_Received",
        "Receiving_Currency",
        "Amount_Paid",
        "Payment_Currency",
        "Payment_Format",
        "Is_Laundering",
        "attack_id",
        "pattern_name",
        "attack_details"
    ]
    writer.writerow(header)

    # ... (Insert the robust splitting logic here) ...

    output_blob.upload_from_string(output_buffer.getvalue(), content_type='text/csv')
    output_buffer.close()