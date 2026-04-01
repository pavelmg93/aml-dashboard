/* @bruin
name: aml_dashboard_pmg_dataset.stg_small_patterns
type: bq.sql
depends:
  - create_external_tables
columns:
  - name: transaction_id
    type: string
    description: "Hashed ID of the transaction"
    checks:
      - name: not_null
  - name: Amount_Received
    type: float
    checks:
      - name: non_negative
  - name: Amount_Paid
    type: float
    checks:
      - name: non_negative
  - name: attack_id
    type: string
    description: "Hashed ID of the attack group"
@bruin */
CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_patterns` AS
WITH pattern_data AS (
    SELECT 
        *, 
        'HI' as risk_type, 
        '{{ var.DATASET_SIZE }}' as dataset_size 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.DATASET_SIZE | lower }}_patterns`

    UNION ALL

    SELECT 
        *, 
        'LI' as risk_type, 
        '{{ var.DATASET_SIZE }}' as dataset_size 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.DATASET_SIZE | lower }}_patterns`
)
SELECT 
    -- Generate a unique ID by hashing the core transaction attributes
    -- Robust Transaction Hash (Join Key)
    -- This handles the STRING timestamp conversion
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

    -- Attack Instance Hash (PK for the attack)
    -- This combines the counter with the risk/size to make it globally unique
    FARM_FINGERPRINT(
        TO_JSON_STRING(
            STRUCT(
                CAST(attack_n AS STRING),
                risk_type,
                '{{ var.DATASET_SIZE }}'
            )
        )
    ) AS attack_id,
    *
FROM pattern_data;