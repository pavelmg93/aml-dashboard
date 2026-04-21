/* @bruin
name: aml_bq.all_transactions
type: bq.sql
materialization:
  type: table
  partition_by: "TIMESTAMP_TRUNC(Timestamp, MONTH)"
  cluster_by: ["Timestamp", "Account"]
depends:
  - aml_bq.stg_small_trans
  - aml_bq.stg_small_attacks
  - aml_bq.ref_small_attack_patterns
@bruin */

-- Bruin handles the CREATE TABLE logic automatically. 
-- Just provide the SELECT statement.
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
    a.attack_id,
    a.pattern_name,
    a.attack_details,
    p.pattern_description,
    CASE 
        WHEN t.Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans` t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_attacks` a
  ON t.attack_id = a.attack_id
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ref_{{ var.DATASET_SIZE | lower }}_attack_patterns` p
  ON a.pattern_name = p.pattern_name