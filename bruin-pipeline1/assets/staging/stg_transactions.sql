/* @bruin
name: stg_transactions
type: bq.sql
depends:
  - create_external_tables
  - stg_patterns
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_trans` AS
WITH raw_trans AS (
    SELECT
        *, 'HI' as risk_type,
        '{{ var.dataset_size }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.dataset_size | lower }}_trans`
    UNION ALL
    SELECT
        *, 'LI' as risk_type,
        '{{ var.dataset_size }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.dataset_size | lower }}_trans`
),
hashed_trans AS (
    SELECT 
        FARM_FINGERPRINT(
            TO_JSON_STRING(
                STRUCT(
                    -- Use FORMAT_TIMESTAMP to match the "YYYY-MM-DD HH:MM" format
                    FORMAT_TIMESTAMP('%Y-%m-%d %H:%M', Timestamp) AS ts,
                    LPAD(TRIM(CAST(From_Bank AS STRING)), 6, '0') AS fb,
                    TRIM(CAST(Account AS STRING)) AS acc,
                    LPAD(TRIM(CAST(To_Bank AS STRING)), 6, '0') AS tb,
                    TRIM(CAST(Account_4 AS STRING)) AS acc4,
                    FORMAT('%.2f', ROUND(Amount_Received, 2)) AS amt
                )
            )
        ) AS transaction_id,
        *
    FROM raw_trans
)

SELECT 
    t.*,
    -- Pull the unique hash from patterns
    p.attack_id AS attack_id
FROM hashed_trans t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns` p
  ON t.transaction_id = p.transaction_id 
  AND t.risk_type = p.risk_type;