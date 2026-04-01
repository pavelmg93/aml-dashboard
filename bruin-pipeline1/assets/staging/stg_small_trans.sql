/* @bruin
name: aml_dashboard_pmg_dataset.stg_small_trans
type: bq.sql
depends:
  - create_external_tables
  - aml_dashboard_pmg_dataset.stg_small_patterns
columns:
  - name: transaction_id
    type: string
    description: "Hashed ID of the transaction"
    checks:
      - name: not_null
      - name: unique
  - name: Amount_Received
    type: float
    checks:
      - name: non_negative
  - name: Amount_Paid
    type: float
    checks:
      - name: non_negative
  - name: Is_Laundering
    type: integer
    checks:
      - name: not_null
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_trans` AS
WITH raw_trans AS (
    SELECT
        *, 'HI' as risk_type,
        '{{ var.DATASET_SIZE }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_trans`
    UNION ALL
    SELECT
        *, 'LI' as risk_type,
        '{{ var.DATASET_SIZE }}' as dataset_size
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_trans`
),
hashed_trans AS (
    SELECT 
        FARM_FINGERPRINT(
            TO_JSON_STRING(
                STRUCT(
                    -- Use identical string manipulation to prevent zero-padding divergences
                    REPLACE(SUBSTR(TRIM(Timestamp), 1, 16), '/', '-') AS ts,
                    
                    -- Use NULLIF to collapse empty strings into NULLs, ensuring identical JSON omission
                    LPAD(NULLIF(TRIM(CAST(From_Bank AS STRING)), ''), 6, '0') AS fb,
                    NULLIF(TRIM(CAST(Account AS STRING)), '') AS acc,
                    LPAD(NULLIF(TRIM(CAST(To_Bank AS STRING)), ''), 6, '0') AS tb,
                    NULLIF(TRIM(CAST(Account_4 AS STRING)), '') AS acc4,
                    
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
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_patterns` p
  ON t.transaction_id = p.transaction_id 
  AND t.risk_type = p.risk_type;