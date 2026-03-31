/* @bruin
name: stg_patterns
type: bq.sql
depends:
  - convert_patterns_to_csv
@bruin */
CREATE TABLE IF NOT EXISTS `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns` AS
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
FROM pattern_data;