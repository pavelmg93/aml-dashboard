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

    attack_id = 0
    in_attack_block = False
    pattern_name = ""
    attack_details = ""

    logging.info(f"Streaming data from {input_path}...")

    # 3. Read directly from GCS and process line-by-line
    with input_blob.open("r", encoding="utf-8") as f_in:
        for line in f_in:
            line = line.strip()
            if not line: continue

            # Detect Start of Block
            if line.startswith("BEGIN LAUNDERING ATTEMPT"):
                in_attack_block = True
                attack_id += 1
                
                # 1. Safely split by the first dash
                parts = line.split('-', 1)
                if len(parts) > 1:
                    # 2. Safely split by the first colon
                    sub_parts = parts[1].split(':', 1)
                    pattern_name = sub_parts[0].strip()
                    
                    # 3. Check if details actually exist after the colon
                    attack_details = sub_parts[1].strip() if len(sub_parts) > 1 else "No details provided"
                else:
                    # Fallback if the line is just the header with no metadata
                    pattern_name = "Unknown Pattern"
                    attack_details = "N/A"
                continue
            
            # Detect End of Block
            if line.startswith("END LAUNDERING ATTEMPT"):
                in_attack_block = False
                continue
            
            # Process Data Rows
            if in_attack_block:
                raw_fields = line.split(',')
                # Append metadata to the transaction fields
                row = raw_fields + [attack_id, pattern_name, attack_details]
                writer.writerow(row)

    output_blob.upload_from_string(output_buffer.getvalue(), content_type='text/csv')
    output_buffer.close()