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
    FARM_FINGERPRINT(
        TO_JSON_STRING(
            STRUCT(
                -- Convert "2022/09/01 00:06" to "2022-09-01 00:06"
                REPLACE(SUBSTR(Timestamp, 1, 16), '/', '-') AS ts, 
                -- Ensure the Bank ID string has leading zeros (in case they were stripped)
                LPAD(From_Bank, 6, '0') AS fb, 
                Account AS acc, 
                LPAD(To_Bank, 6, '0') AS tb, 
                Account_4 AS acc4, 
                -- Round the FLOAT
                CAST(ROUND(Amount_Received, 2) AS STRING) AS amt
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