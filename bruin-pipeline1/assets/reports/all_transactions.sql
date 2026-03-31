/* @bruin
name: all_transactions
type: bq.sql
depends:
  - stg_transactions
@bruin */

-- This view acts as the final source for your Dashboard
SELECT 
    transaction_key,
    Timestamp,
    Account,
    Amount_Received,
    Receiving_Currency,
    risk_type,
    dataset_size,
    -- Add business logic like USD conversion here
    CASE 
        WHEN Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_transactions`;