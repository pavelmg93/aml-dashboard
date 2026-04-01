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
    -- Union HI and LI accounts to get the master list
    SELECT *, 'HI' as risk_profile FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE }}_accounts`
    UNION ALL
    SELECT *, 'LI' as risk_profile FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE }}_accounts`
),

outgoing_stats AS (
    -- Account as SENDER (Debit)
    SELECT 
        From_Bank AS Bank_ID,
        Account AS Account_Number,
        SUM(Amount_Paid) as total_debited,
        COUNT(transaction_id) as sent_count,
        COUNT(DISTINCT attack_id) as outgoing_attack_count,
        SUM(CASE WHEN Is_Laundering = 1 THEN Amount_Paid ELSE 0 END) as laundering_out_value
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans`
    GROUP BY 1, 2
),

incoming_stats AS (
    -- Account as RECEIVER (Credit)
    SELECT 
        To_Bank AS Bank_ID,
        Account_4 AS Account_Number,
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
    a.Bank_ID,
    a.Account_Number,
    a.risk_profile,
    -- Calculation: Credits (In) - Debits (Out)
    (COALESCE(i.total_credited, 0) - COALESCE(o.total_debited, 0)) as current_balance,
    -- Combined count of unique attacks this account touched
    (COALESCE(o.outgoing_attack_count, 0) + COALESCE(i.incoming_attack_count, 0)) as used_in_attacks,
    -- Transaction Volume
    (COALESCE(o.sent_count, 0) + COALESCE(i.received_count, 0)) as total_transactions,
    -- Laundering Value (Total coming in or going out flagged as laundering)
    (COALESCE(o.laundering_out_value, 0) + COALESCE(i.laundering_in_value, 0)) as total_laundering_value
FROM account_base a
LEFT JOIN outgoing_stats o 
    ON CAST(a.Bank_ID AS STRING) = CAST(o.Bank_ID AS STRING) 
    AND CAST(a.Account_Number AS STRING) = CAST(o.Account_Number AS STRING)
LEFT JOIN incoming_stats i 
    ON CAST(a.Bank_ID AS STRING) = CAST(i.Bank_ID AS STRING) 
    AND CAST(a.Account_Number AS STRING) = CAST(i.Account_Number AS STRING);