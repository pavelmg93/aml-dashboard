/* @bruin
name: stg_attacks
type: bq.sql
depends:
  - stg_patterns
@bruin */

CREATE TABLE IF NOT EXISTS `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_attacks` AS
SELECT DISTINCT
    -- Generate a unique ID by hashing the core transaction attributes
    FARM_FINGERPRINT(
        TO_JSON_STRING(
            STRUCT(
                attack_id AS STRING,
                risk_type,
                dataset_size
            )
        )
    ) AS attack_instance_id,
    pattern_name,
    attack_details,
    risk_type,
    dataset_size
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.stg_{{ var.dataset_size | lower }}_patterns`;