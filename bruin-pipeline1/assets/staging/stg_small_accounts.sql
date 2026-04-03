/* @bruin
name: aml_dashboard_pmg_dataset.stg_small_accounts
type: bq.sql
depends:
  - aml_dashboard_pmg_dataset.stg_small_attacks
  - aml_dashboard_pmg_dataset.stg_small_trans
columns:
  - name: Account_Number
    type: string
    checks:
      - name: not_null
  - name: used_in_attacks
    type: integer
    description: "Total number of distinct attacks this account was involved in"
    checks:
      - name: non_negative
  - name: total_transactions
    type: integer
    checks:
      - name: non_negative
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE }}_accounts` AS
WITH account_base AS (
    SELECT 
        *, 
        'HI' as risk_type 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_accounts`
    UNION ALL
    SELECT 
        *, 
        'LI' as risk_type 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_accounts`
),

outgoing_stats AS (
    SELECT 
        -- The Integer Strip for Bank IDs
        CAST(CAST(From_Bank AS INT64) AS STRING) AS Bank_ID,
        TRIM(CAST(Account AS STRING)) AS Account_Number,
        SUM(Amount_Paid) as total_debited,
        COUNT(transaction_id) as sent_count,
        COUNT(DISTINCT attack_id) as outgoing_attack_count,
        SUM(CASE WHEN Is_Laundering = 1 THEN Amount_Paid ELSE 0 END) as laundering_out_value
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans`
    GROUP BY 1, 2
),

incoming_stats AS (
    SELECT 
        -- The Integer Strip for Bank IDs
        CAST(CAST(To_Bank AS INT64) AS STRING) AS Bank_ID,
        TRIM(CAST(Account_4 AS STRING)) AS Account_Number,
        SUM(Amount_Received) as total_credited,
        COUNT(transaction_id) as received_count,
        COUNT(DISTINCT attack_id) as incoming_attack_count,
        SUM(CASE WHEN Is_Laundering = 1 THEN Amount_Received ELSE 0 END) as laundering_in_value
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans`
    GROUP BY 1, 2
)

SELECT 
    a.Entity_Name,
    a.Entity_ID,
    a.Bank_Name,
    -- Strip the base account keys too so everything matches 1-to-1
    CAST(CAST(a.Bank_ID AS INT64) AS STRING) AS Bank_ID,
    TRIM(CAST(a.Account_Number AS STRING)) AS Account_Number,
    a.risk_type,
    (COALESCE(i.total_credited, 0) - COALESCE(o.total_debited, 0)) as current_balance,
    (COALESCE(o.outgoing_attack_count, 0) + COALESCE(i.incoming_attack_count, 0)) as used_in_attacks,
    (COALESCE(o.sent_count, 0) + COALESCE(i.received_count, 0)) as total_transactions,
    (COALESCE(o.laundering_out_value, 0) + COALESCE(i.laundering_in_value, 0)) as total_laundering_value
FROM account_base a
LEFT JOIN outgoing_stats o 
    ON CAST(CAST(a.Bank_ID AS INT64) AS STRING) = o.Bank_ID 
    AND TRIM(CAST(a.Account_Number AS STRING)) = o.Account_Number
LEFT JOIN incoming_stats i 
    ON CAST(CAST(a.Bank_ID AS INT64) AS STRING) = i.Bank_ID 
    AND TRIM(CAST(a.Account_Number AS STRING)) = i.Account_Number;