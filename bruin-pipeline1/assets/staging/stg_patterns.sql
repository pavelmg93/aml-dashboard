/* @bruin
name: stg_patterns
type: bq.sql
depends:
  - create_external_tables
@bruin */
CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns` AS
WITH pattern_data AS (
    SELECT 
        *, 
        'HI' as risk_type, 
        '{{ var.dataset_size }}' as dataset_size 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_hi_{{ var.dataset_size | lower }}_patterns`

    UNION ALL

    SELECT 
        *, 
        'LI' as risk_type, 
        '{{ var.dataset_size }}' as dataset_size 
    FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ext_li_{{ var.dataset_size | lower }}_patterns`
)
SELECT 
    -- Generate a unique ID by hashing the core transaction attributes
    -- Robust Transaction Hash (Join Key)
    -- This handles the STRING timestamp conversion
    FARM_FINGERPRINT(
        TO_JSON_STRING(
            STRUCT(
                REPLACE(SUBSTR(TRIM(Timestamp), 1, 16), '/', '-') AS ts,
                LPAD(TRIM(CAST(From_Bank AS STRING)), 6, '0') AS fb,
                TRIM(CAST(Account AS STRING)) AS acc,
                LPAD(TRIM(CAST(To_Bank AS STRING)), 6, '0') AS tb,
                TRIM(CAST(Account_4 AS STRING)) AS acc4,
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
                '{{ var.dataset_size }}'
            )
        )
    ) AS attack_id,
    *
FROM pattern_data;