/* @bruin
name: stg_transactions
type: bq.sql
depends:
  - create_external_tables
@bruin */

CREATE IF NOT EXISTS `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans` AS
-- Union HI and LI transactions for the current dataset size
WITH
    hi_trans AS (
        SELECT *, 'HI' as risk_type, '{{ var.DATASET_SIZE }}' as dataset_size
        FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_trans`
),
    li_trans AS (
        SELECT *, 'LI' as risk_type, '{{ var.DATASET_SIZE }}' as dataset_size
        FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_trans`
)

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
FROM hi_trans
UNION ALL
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
FROM li_trans;