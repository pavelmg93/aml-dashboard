/* @bruin
name: aml_bq.stg_small_patterns
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
    risk_type,
    dataset_size,
    -- 1. Deterministic Transaction ID (The Primary Key)
    FARM_FINGERPRINT(
        CONCAT(
            COALESCE(CAST(Timestamp AS STRING), ''),
            COALESCE(CAST(CAST(From_Bank AS INT64) AS STRING), ''),
            COALESCE(TRIM(CAST(Account AS STRING)), ''),
            COALESCE(CAST(CAST(To_Bank AS INT64) AS STRING), ''),
            COALESCE(TRIM(CAST(Account_4 AS STRING)), ''),
            COALESCE(CAST(Amount_Paid AS STRING), '')
        )
    ) AS transaction_id,

    -- 2. Normalized Fields
    Timestamp,
    CAST(CAST(From_Bank AS INT64) AS STRING) AS From_Bank,
    TRIM(CAST(Account AS STRING)) AS Account,
    CAST(CAST(To_Bank AS INT64) AS STRING) AS To_Bank,
    TRIM(CAST(Account_4 AS STRING)) AS Account_4,
    
    -- 3. Raw Values
    Amount_Received,
    Receiving_Currency,
    Amount_Paid,
    Payment_Currency,
    Payment_Format,
    Is_Laundering,

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
    attack_n,
    pattern_name,
    attack_details
FROM pattern_data;