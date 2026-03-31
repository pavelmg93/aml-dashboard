/* @bruin
name: stg_transactions
type: bq.sql
depends:
  - create_external_tables
  - stg_patterns
@bruin */

CREATE TABLE IF NOT EXISTS `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_trans` AS
WITH raw_trans AS (
    SELECT *, 'HI' as risk_type, '{{ var.dataset_size }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.dataset_size | lower }}_trans`
    UNION ALL
    SELECT *, 'LI' as risk_type, '{{ var.dataset_size }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.dataset_size | lower }}_trans`
),
hashed_trans AS (
    SELECT 
        -- Generate a unique ID by hashing the core transaction attributes
        FARM_FINGERPRINT(
            TO_JSON_STRING(
                STRUCT(
                    Timestamp, 
                    From_Bank, 
                    Account, 
                    To_Bank, 
                    Account_4, 
                    Amount_Received
                )
            )
        ) AS transaction_id,
        *
    FROM raw_trans
)

SELECT 
    t.* EXCEPT(attack_id, pattern_name, attack_details),
    -- Link to the unique attack instance
    p.attack_instance_id AS attack_id
FROM hashed_trans t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns` p
  ON t.transaction_id = p.transaction_id 
  AND t.risk_type = p.risk_type;