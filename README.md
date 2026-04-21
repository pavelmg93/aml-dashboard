# Anti-Money Laundering (AML) Dashboard

A data pipeline and forensic dashboard for Compliance Officers, built on the IBM AML synthetic dataset.

### Live Dashboard
[**View the AML Dashboard in Looker Studio**](https://datastudio.google.com/reporting/78f521cd-3007-4151-9cd3-fe4a107d4e8c/page/VdnvF)

*(Screenshots of the dashboard in action)*
![AML Dashboard Main View](./images/aml-pmg-dashboard.png)
![AML Dashboard Network Flow](./images/network_flow.jpg)

---

## Project Overview
This project transforms the IBM AML synthetic dataset into a Walkable Graph of illicit money flows using an 11-field deterministic hashing strategy. 

A core feature of the data preparation is the automated Python parsing script. The IBM dataset provides laundering attack patterns in a complex text format. The pipeline streams this raw text directly from Google Cloud Storage, parses the specific attack blocks, flattens the nested data into tabular rows, and saves it as a clean CSV ready for BigQuery external tables.

---

## The Dataset (IBM Synthetic AML Data)
Source: IBM Transactions for Anti Money Laundering (AML)

Money laundering is a multi-billion dollar issue, yet access to real financial data is highly restricted for privacy reasons. Detection is notoriously difficult, plagued by high false positive rates and sophisticated criminals hiding their tracks.

This project utilizes IBM’s Synthetic Transaction Data, which models a virtual world of individuals, companies, and banks. Unlike real-world datasets that provide a fragmented view, this dataset tracks funds through an entire financial ecosystem across multiple banks.

### Key Characteristics:
* Full Cycle Modeling: Captures the entire laundering journey: Placement (smuggling illicit funds), Layering (mixing funds), and Integration (spending).
* Ground Truth Labeling: Tracks illicit funds through arbitrarily many transactions, enabling labels many steps removed from the source.
* Risk Groups: 
    * Group HI: Higher Illicit ratio (more laundering).
    * Group LI: Lower Illicit ratio (less laundering).
* Scaling: Provided in Small (approx 5M trans), Medium (approx 32M trans), and Large (approx 180M trans) sets. This project defaults to the Small set for optimized processing.
* Typology Mapping: Provides text-based logs for 8 specific laundering patterns introduced in the AMLSim simulator, which we parse and join to the core transaction ledger.

---

## Infrastructure and Pipeline Implementation Notes

### 1. GCP Authentication and Pathing Strategy
Mixing Google Cloud SDK Application Default Credentials (ADC) with dedicated Service Account JSON keys caused quota and context collisions. The setup script generates a .env that handles two distinct pathing needs:
* GOOGLE_APPLICATION_CREDENTIALS (Absolute Path): Required by system-wide Python libraries to find the key regardless of the execution directory.
* BRUIN_GCP_KEY (Relative Path): Used by the Bruin CLI to keep the project portable across different developer machines.

### 2. Configuration Drift (Terraform vs. Bruin)
Hardcoding resources across multiple tools led to naming conflicts (e.g., GCS buckets use hyphens "-", while BigQuery strictly requires underscores "_"). The .env file serves as the Single Source of Truth. The setup script dynamically injects these variables into both variables.tf and pipeline.yml using bash Here Documents.

### 3. Docker Persistence and Stay-Alive Strategy
Standard Docker containers exit as soon as their primary task finishes, making it impossible to exec multiple pipeline commands into a running environment. We implemented a two-container architecture (Runner and Client). The Runner uses a tail -f /dev/null command to remain active as a persistent background engine. This allows for seamless execution of Terraform and Bruin commands without restarting the environment.

---

## Data Forensic Logic

### 1. Unique ID Engineering (Deterministic Hashing)
The raw dataset lacks a native primary key. We engineered a deterministic 64-bit integer hash to link transactions across pipeline stages. Since BigQuery does not allow partitioning by FLOAT64, all numeric fields are cast to strings and trimmed before hashing.

```sql
-- Snippet from Staging.stg_small_trans
FARM_FINGERPRINT(
    CONCAT(
        COALESCE(CAST(Timestamp AS STRING), ''),
        COALESCE(CAST(CAST(From_Bank AS INT64) AS STRING), ''),
        COALESCE(TRIM(CAST(Account AS STRING)), ''),
        COALESCE(CAST(Amount_Paid AS STRING), '')
    )
) AS transaction_id
```

### 2. Deduplication Strategy
To prevent inflated laundering volumes, we identify identical rows by grouping across all transaction fields and keeping only the first occurrence.

```sql
-- Deduplication via Row Numbering
ROW_NUMBER() OVER (
    PARTITION BY 
        Timestamp, From_Bank, Account, To_Bank, Account_4, 
        CAST(Amount_Paid AS STRING)
    ORDER BY Timestamp
) as row_num
-- Filtered in subsequent step via WHERE row_num = 1
```

---

## Performance Engineering (The Walkable Graph)

To optimize the Looker Studio experience, we moved from raw Views to Materialized Tables. This allows for the use of Partitioning and Clustering to physically organize data for forensic analysis.

### Partitioning and Clustering (Presorting)
We partition by month to limit data scan costs and cluster by Timestamp and Account. This feature, known as Clustering, handles the presorting for network flow logic, ensuring that an account's transaction history is stored in adjacent blocks.

```sql
/* @bruin
name: Reports.all_transactions
type: bq.sql
materialization: table
depends:
  - Staging.stg_small_trans
  - Staging.stg_small_attacks
  - Ingestion.ref_small_attack_patterns
@bruin */

CREATE OR REPLACE TABLE `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.all_transactions`
PARTITION BY TIMESTAMP_TRUNC(Timestamp, MONTH)
CLUSTER BY Timestamp, Account
AS
SELECT 
    t.Timestamp,
    t.Account,
    t.Amount_Paid,
    t.transaction_id,
    a.pattern_name,
    p.pattern_description,
    CASE 
        WHEN t.Is_Laundering = 1 THEN 'High Alert'
        ELSE 'Normal'
    END as status
FROM `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Staging.stg_{{ var.DATASET_SIZE | lower }}_trans` t
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Staging.stg_{{ var.DATASET_SIZE | lower }}_attacks` a
  ON t.attack_id = a.attack_id
LEFT JOIN `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET }}.Ingestion.ref_{{ var.DATASET_SIZE | lower }}_attack_patterns` p
  ON a.pattern_name = p.pattern_name;
```

---

## Execution Guide

### Docker Compose Flow (Daisy-Chain)
Use the dc-go command for a fully interactive setup and execution.

| Command | Description |
| :--- | :--- |
| make dc-build | Builds the Docker images for the Runner and Client. |
| make dc-setup | Starts interactive environment configuration inside the container. |
| make dc-go | The All-in-One command: Starts services and chains setup, infra, and pipeline. |
| make dc-dashboard | Fetches the live dashboard URL from the Client container. |
| make dc-down | Stops services and cleans up local Docker volumes. |
| make dc-clean | Deep clean: Destroys GCP infrastructure and purges all local Docker artifacts. |

### Local Flow
| Command | Description |
| :--- | :--- |
| make setup | Installs tools and automatically triggers virtual environment setup. |
| make infra | Provisions GCS and BigQuery via Terraform. |
| make pipeline | Executes the Ingestion -> Staging -> Reports journey. |
| make dashboard | Displays the Looker Studio URL for the Gold data. |
| make clean | Destroys all GCP infrastructure. |

---

## Project Structure

```text
.
├── Makefile
├── Dockerfile             # Multi-stage build for all core tools
├── docker-compose.yml     # Runner/Client persistent architecture
├── README.md
├── .bruin.yml
├── .env                   # (Generated Single Source of Truth)
├── bruin-pipeline1/
│   ├── pipeline.yml
│   └── assets/
│       ├── Ingestion/      # Raw data and pattern references
│       ├── Staging/        # Normalized tables and parsing scripts
│       └── Reports/        # Materialized Gold layer for Dashboard
├── terraform/              # Infrastructure as Code
├── scripts/                # Setup and automation scripts
└── keys/                   # Google Cloud JSON keys
```

---

## Future Roadmap
* dlt Integration: Automating the raw data ingestion from Kaggle using the data load tool.
* Graph Visualization: Exploring Neo4j or specialized Looker Studio visualizations to represent the money flow network.
* Streaming: Real-time simulation using Red Panda or Kafka for live detection modeling.