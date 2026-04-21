/* @bruin
name: DTST.stg_small_trans
type: bq.sql
depends:
  - create_external_tables
  - DTST.stg_small_patterns
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

        -- Assign a unique number to identical rows
        ROW_NUMBER() OVER (
            PARTITION BY 
                Timestamp, From_Bank, Account, To_Bank, Account_4, 
                CAST(Amount_Paid AS STRING)
            ORDER BY Timestamp
        ) as row_num
    FROM raw_trans
)
SELECT 
    t.* EXCEPT(row_num),
    -- Pull the unique hash from patterns
    p.attack_id AS attack_id
FROM hashed_trans t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_patterns` p
  ON t.transaction_id = p.transaction_id 
  AND t.risk_type = p.risk_type
WHERE t.row_num = 1;