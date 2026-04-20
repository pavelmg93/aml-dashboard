/* @bruin
name: aml_bq.stg_small_attacks
type: bq.sql
depends:
  - aml_bq.stg_small_patterns
columns:
  - name: attack_id
    type: string
    description: "Unique identifier for a specific laundering attempt"
    checks:
      - name: not_null
      - name: unique
  - name: pattern_name
    type: string
    checks:
      - name: not_null
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE }}_attacks` AS
SELECT DISTINCT
    attack_id,
    pattern_name,
    attack_details,
    risk_type,
    '{{ var.DATASET_SIZE }}' as dataset_size
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE | lower }}_patterns`;