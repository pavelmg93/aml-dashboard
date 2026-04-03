/* @bruin
name: aml_dashboard_pmg_dataset.ref_small_attack_patterns
type: bq.sql
depends:
  - aml_dashboard_pmg_dataset.stg_small_attacks
columns:
  - name: pattern_name
    type: string
    description: "Distinct name of the laundering pattern"
    checks:
      - name: not_null
      - name: unique
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ref_{{ var.DATASET_SIZE }}_attack_patterns` AS
SELECT DISTINCT
    pattern_name,
    -- This field is initialized as null for manual population later
    CAST(NULL AS STRING) AS pattern_description
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.DATASET_SIZE }}_attacks`;