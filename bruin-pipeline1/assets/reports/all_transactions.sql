/* @bruin
name: Reports.all_transactions
type: bq.sql
depends:
  - Staging.stg_small_trans
  - Staging.stg_small_attacks
  - Ingestion.ref_small_attack_patterns
@bruin */

-- Partitioning by month limits the amount of data scanned by Looker Studio filters
-- Clustering (presorting) by Timestamp and Account groups related transaction nodes together
CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.all_transactions`
PARTITION BY TIMESTAMP_TRUNC(Timestamp, MONTH)
CLUSTER BY Timestamp, Account
AS
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
    -- Descriptive info from the Staging Attacks table
    a.pattern_name,
    a.attack_details,
    -- Manual description from the Ingestion reference table
    p.pattern_description,
    -- Risk status logic
    CASE 
        WHEN t.Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Staging.stg_{{ var.DATASET_SIZE | lower }}_trans` t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Staging.stg_{{ var.DATASET_SIZE | lower }}_attacks` a
  ON t.attack_id = a.attack_id
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Ingestion.ref_{{ var.DATASET_SIZE | lower }}_attack_patterns` p
  ON a.pattern_name = p.pattern_name;