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
                    -- Convert TIMESTAMP to "YYYY-MM-DD HH:MM"
                    FORMAT_TIMESTAMP('%Y-%m-%d %H:%M', Timestamp) AS ts, 
                    -- Pad the INTEGER Bank IDs to 6-digit strings
                    LPAD(CAST(From_Bank AS STRING), 6, '0') AS fb, 
                    CAST(Account AS STRING) AS acc, 
                    LPAD(CAST(To_Bank AS STRING), 6, '0') AS tb, 
                    CAST(Account_4 AS STRING) AS acc4, 
                    -- Round the FLOAT to match the CSV
                    CAST(ROUND(Amount_Received, 2) AS STRING) AS amt
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