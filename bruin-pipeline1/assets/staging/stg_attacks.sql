/* @bruin
name: stg_attacks
type: bq.sql
depends:
  - stg_patterns
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_attacks` AS
SELECT DISTINCT
    attack_id,
    pattern_name,
    attack_details,
    risk_type,
    '{{ var.dataset_size }}' as dataset_size
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns`;