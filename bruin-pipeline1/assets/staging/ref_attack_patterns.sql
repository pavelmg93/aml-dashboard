/* @bruin
name: ref_attack_patterns
type: bq.sql
depends:
  - stg_attacks
@bruin */

CREATE TABLE IF NOT EXISTS `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.ref_attack_patterns` AS
SELECT DISTINCT
    pattern_name,
    -- This field is initialized as null for manual population later
    CAST(NULL AS STRING) AS pattern_description
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_attacks`;