/* @bruin
name: create_external_tables
type: bq.sql
connection: gcp_conn
depends:
  - convert_patterns_to_csv
@bruin */

-- 1. High-Risk (HI) Small Transactions
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_trans`
(
    Timestamp STRING,
    From_Bank STRING,
    Account STRING,
    To_Bank STRING,
    Account_4 STRING,
    Amount_Received FLOAT64,
    Receiving_Currency STRING,
    Amount_Paid FLOAT64,
    Payment_Currency STRING,
    Payment_Format STRING,
    Is_Laundering INT64
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://{{ var.GCP_BUCKET }}/raw/ibm_aml/HI-Small_Trans.csv'],
  skip_leading_rows = 1
);


-- 2. High-Risk (HI) Small Accounts
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_accounts`
(
    Bank_Name	STRING,
    Bank_ID	STRING,
    Account_Number STRING,
    Entity_ID	STRING,
    Entity_Name STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://{{ var.GCP_BUCKET }}/raw/ibm_aml/HI-Small_accounts.csv'],
  skip_leading_rows = 1
);

-- 3. Low-Risk (LI) Small Transactions
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_trans`
(
    Timestamp STRING,
    From_Bank STRING,
    Account STRING,
    To_Bank STRING,
    Account_4 STRING,
    Amount_Received FLOAT64,
    Receiving_Currency STRING,
    Amount_Paid FLOAT64,
    Payment_Currency STRING,
    Payment_Format STRING,
    Is_Laundering INT64
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://{{ var.GCP_BUCKET }}/raw/ibm_aml/LI-Small_Trans.csv'],
  skip_leading_rows = 1
);

-- 4. Low-Risk (LI) Small Accounts
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_accounts`
(
    Bank_Name	STRING,
    Bank_ID	STRING,
    Account_Number STRING,
    Entity_ID	STRING,
    Entity_Name STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://{{ var.GCP_BUCKET }}/raw/ibm_aml/LI-Small_accounts.csv'],
  skip_leading_rows = 1
);

-- 5. HI Flattened AML Patterns
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_patterns`
(
    Timestamp STRING,
    From_Bank STRING,
    Account STRING,
    To_Bank STRING,
    Account_4 STRING,
    Amount_Received FLOAT64,
    Receiving_Currency STRING,
    Amount_Paid FLOAT64,
    Payment_Currency STRING,
    Payment_Format STRING,
    Is_Laundering INT64,
    attack_n INT64,
    pattern_name STRING,
    attack_details STRING
)
OPTIONS (
  format = 'CSV',
  -- Use lower to match the processed filename from Python
  uris = ['gs://{{ var.GCP_BUCKET }}/processed/ibm-aml/HI_{{ var.DATASET_SIZE | lower }}_patterns_flat.csv'],
  skip_leading_rows = 1
);

-- 6. LI Flattened AML Patterns
CREATE OR REPLACE EXTERNAL TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_patterns`
(
    Timestamp STRING,
    From_Bank STRING,
    Account STRING,
    To_Bank STRING,
    Account_4 STRING,
    Amount_Received FLOAT64,
    Receiving_Currency STRING,
    Amount_Paid FLOAT64,
    Payment_Currency STRING,
    Payment_Format STRING,
    Is_Laundering INT64,
    attack_n INT64,
    pattern_name STRING,
    attack_details STRING
)
OPTIONS (
  format = 'CSV',
  -- Use lower to match the processed filename from Python
  uris = ['gs://{{ var.GCP_BUCKET }}/processed/ibm-aml/LI_{{ var.DATASET_SIZE | lower }}_patterns_flat.csv'],
  skip_leading_rows = 1
);