/* @bruin
name: all_transactions
type: bq.sql
depends:
  - stg_transactions
  - stg_attacks
  - ref_attack_patterns
@bruin */

-- This view joins the normalized tables to create the final Dashboard source
SELECT 
    t.Timestamp,
    t.From_Bank,
    t.Account,
    t.To_Bank,
    t.Account_4,               
    t.Amount_Received,
    t.Receiving_Currency,
    t.Amount_Paid,
    t.Payment_Currency,
    t.Payment_Format,
    t.Is_Laundering,
    t.transaction_id,
    t.risk_type,
    t.dataset_size,
    -- Pulling descriptive info from the Attacks table
    a.pattern_name,
    a.attack_details,
    -- Pulling the manual description from the Patterns reference table
    p.pattern_description,
    -- Business Logic
    CASE 
        WHEN t.Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_trans` t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_attacks` a
  ON t.attack_id = a.attack_id
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ref_attack_patterns` p
  ON a.pattern_name = p.pattern_name;