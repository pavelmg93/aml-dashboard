/* @bruin
name: all_transactions
type: bq.sql
depends:
  - stg_transactions
@bruin */

-- This view acts as the final source for your Dashboard
SELECT 
    Timestamp,
    From_Bank,
    Account,
    To_Bank,
    Account_4,               
    Amount_Received,
    Receiving_Currency,
    Amount_Paid,
    Payment_Currency,
    Payment_Format,
    Is_Laundering,
    attack_id,
    pattern_name,
    attack_details,
    transaction_id,
    risk_type,
    dataset_size,
    -- Add business logic like USD conversion here
    CASE 
        WHEN Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_trans`;