# Anti-Money Laundering (AML) Dashboard

I built this ETL pipeline and forensic dashboard to help Compliance Officers visualize illicit money flows using the IBM AML synthetic dataset.

### Live Dashboard Template
[**View the AML Dashboard in Looker Studio**](https://datastudio.google.com/reporting/78f521cd-3007-4151-9cd3-fe4a107d4e8c/page/VdnvF)

**Note on Dashboard Usage:** To use this dashboard with your own data, a Google Account with Google Cloud and BigQuery enabled is required. The link above serves as a template; once you execute the ETL pipeline, this link can be transformed into your custom dashboard URL, specifically visualizing the data hosted in your personal BigQuery environment.

![AML Dashboard Main View](./images/aml-pmg-dashboard.png)

---

## Project Overview
This project transforms raw synthetic financial data into a **"Walkable Graph"** of illicit money flows. By implementing an 11-field deterministic hashing strategy, I developed an **ETL pipeline** that allows investigators to trace funds across multiple institutions and identify complex criminal behaviors that traditional, fragmented systems often miss.

A core feature of my data preparation is the automated Python parsing script. The IBM dataset provides laundering attack patterns in a complex text format. My ETL pipeline streams this raw text directly from Google Cloud Storage, parses the specific attack blocks, flattens the nested data into tabular rows, and saves it as a clean CSV ready for BigQuery external tables.

---

## The Tech Stack

I selected this stack to satisfy the requirements of a production-grade cloud data platform, ensuring scalability, reproducibility, and clear separation of concerns.

* **Infrastructure as Code (IaC): Terraform**
    I use Terraform to provision the entire Google Cloud environment. This ensures that the GCS buckets and BigQuery datasets are version-controlled and can be destroyed or recreated in minutes. It eliminates configuration drift by managing resource states centrally.
* **Data Lake: Google Cloud Storage (GCS)**
    GCS acts as my landing zone for raw Kaggle data and the primary storage for my parsed CSV files. It provides a cost-effective, durable storage layer that BigQuery can query directly via external tables during the **Staging** phase.
* **Data Warehouse: BigQuery**
    BigQuery serves as the compute engine for my ETL. I utilize its massive parallel processing power to perform complex JOINs between millions of transaction records and attack typologies. I leverage its analytical features, such as partitioning and clustering, to optimize query performance for the dashboard.
* **Isolation: Docker Compose**
    I containerized the entire environment using Docker to ensure the ETL pipeline is fully portable and reproducible. I implemented a persistent architecture with a dedicated Runner and a Client container.
* **Workflow Orchestration: Bruin**
    Bruin is the brain of the ETL pipeline. I use it to manage dependencies between my Python ingestion scripts, SQL staging transformations, and final **Reports** materializations. It ensures that data flows in the correct order: Ingestion -> Staging -> Reports.
    It helps me run basic data tests and enforce schema.
* **Visualization: Looker Studio (formerly Data Studio)**
    I chose Looker Studio to provide a real-time interface for Compliance Officers. I have implemented forensic charts to satisfy requirements: a network flow visualization and a high-risk transaction ledger. These connect directly to my partitioned BigQuery tables.
* **Package Management: uv**
    I use uv for lightning-fast Python dependency management and reproducible virtual environments, ensuring that my parsing and ingestion scripts run consistently across local and Docker environments.
* **Scripted Setup & Run: Make**
    I used Make with a bash script to guide reviewers/users to a smooth setup, ensuring environment variables all lock in correctly.

---

## The Dataset (IBM Synthetic AML Data)
**Source:** IBM Transactions for Anti Money Laundering (AML)
[**Kaggle Source**](https://www.kaggle.com/datasets/ealtman2019/ibm-transactions-for-anti-money-laundering-aml)

Money laundering is a multi-billion dollar issue, yet access to real financial transaction data is highly restricted for both proprietary and privacy reasons. Detection is notoriously difficult as automated algorithms often have high false positive and false negative rates. This synthetic transaction data from IBM avoids these problems by modeling a virtual world inhabited by individuals, companies, and banks.

### Forensic Discovery: The Orphan Record Challenge
A critical discovery I made during the development of this ETL was that a significant volume of records marked `is_laundering = 1` in the core ledger are **not** associated with any of the 8 defined attack patterns in the raw logs. 

The data generator tracks funds derived from illicit activity through arbitrarily many transactions, creating the ability to label laundering transactions many steps removed from their illicit source. These "orphan" laundering records indicate either background noise generated by the simulator or secondary illicit activities. Identifying these required robust record-matching logic and revealed a gap that standard rule-based systems would fail to categorize.

### Dataset Characteristics
I used this data because it models the full money laundering cycle:
* **Placement:** Sources like smuggling of illicit funds.
* **Layering:** Mixing the illicit funds into the financial system.
* **Integration:** Spending the illicit funds.

The content is divided into groups:
* **Group HI:** Higher illicit ratio (more laundering).
* **Group LI:** Lower illicit ratio (less laundering).
Each contains Small (~5M transactions), Medium (~32M), and Large (~180M) sets. I focused on the HI-Small set for this implementation.

### Citations
If you use these datasets, please cite the following works as requested by the IBM team:
* Paper describing generation of data (Neurips 2023).
* Github Site with GNN Models to Predict Laundering.
* Provably Powerful Graph Neural Networks for Directed Multigraphs.

---

## ETL Architecture & Implementation

### Python Scripting & CSV Creation
The IBM dataset presents a unique challenge: while transactions are provided as CSVs, the "Attack Patterns" are stored in raw, semi-structured text logs. A standard loader cannot interpret these.

**The Parsing Strategy:** My `convert_patterns_to_csv.py` script serves as a custom transformer within the ETL. It performs a stream-parse of raw text logs from Google Cloud Storage:
1. Block Identification: Scans for specific Alert markers indicating the start of a laundering sequence.
2. Attribute Extraction: Uses Regex to pull Step, Amount, Source, and Destination for every hop in the chain.
3. CSV Creation: It flattens nested, multi-hop events into structured CSV rows and streams them back to GCS via my `gcs_utils.py` library.

### Data Forensic Logic: Hashing & Matching
Since the dataset lacks a native `transaction_id`, I engineered a deterministic 64-bit integer hash to act as the primary key. This hash is the **only way** to perform the complex JOIN logic required to link the primary transaction ledger with the parsed attack patterns and typology descriptions.

```sql
-- Deterministic Hashing Snippet from Staging.stg_small_trans
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
```

### Performance Engineering
To optimize the Looker Studio experience, I materialized the **Reports** layer as physical tables rather than views. I use **Partitioning** (by month) and **Clustering** (the presort feature) to group transaction nodes together, ensuring that an investigator searching for a specific account's history finds those records stored in adjacent blocks.

```sql
-- Snippet from Reports.all_transactions highlighting the JOIN and Matching
CREATE OR REPLACE TABLE `project.dataset.all_transactions`
PARTITION BY TIMESTAMP_TRUNC(Timestamp, MONTH)
CLUSTER BY Timestamp, Account
AS
SELECT 
    t.*,
    a.pattern_name,
    p.pattern_description
FROM Staging.stg_small_trans t
LEFT JOIN Staging.stg_small_attacks a 
  ON t.transaction_id = a.transaction_id  -- Matching based on engineered ID
LEFT JOIN Staging.ref_small_attack_patterns p 
  ON a.pattern_name = p.pattern_name;
```

---

## Laundering Attack Patterns
My ETL identifies 8 distinct criminal typologies:
1. Fan-Out: A single source distributes funds to many destination accounts.
2. Fan-In: Multiple accounts consolidate funds into a single gatherer account.
3. Cycle: Funds move through a chain (A -> B -> C -> A) to obscure the trail.
4. Bipartite: A complex mixing network between multiple sources and destinations.
5. Scatter-Gather: Rapid fan-out followed by a quick consolidation.
6. Gather-Scatter: Consolidation followed by immediate redistribution.
7. Random: Simulated noise used to test detection accuracy.
8. Single: A direct, high-volume illicit transfer between two points.

---

## Execution Guide

### Docker Compose Flow (Daisy-Chain)
The `dc-go` command is the recommended interactive way to walk through the ETL. I built this to automate the sequence.

| Command | Description |
| :--- | :--- |
| make dc-build | Builds the Runner and Client images. |
| make dc-setup | Interactive configuration of GCP and Kaggle credentials inside Docker. |
| make dc-go | Chained command: Starts services and executes setup, infra, and ETL pipeline. |
| make dc-dashboard | Fetches the live dashboard URL from the Client container. |
| make dc-down | Stops services and cleans up local Docker volumes. |
| make dc-clean | Deep clean: Purges Docker artifacts and destroys cloud resources. |

---

## Full Project Structure & Asset Directory

```text
.
├── Dockerfile                  # Multi-stage build for all core ETL tools
├── LICENSE
├── Makefile                    # Solo project automation orchestrator
├── README.md                   # Project documentation
├── docker-compose.yaml         # Runner/Client persistent architecture
├── pyproject.toml              # Python dependencies managed via uv
├── uv.lock                     # Lockfile for reproducible builds
├── .bruin.yml                  # Bruin CLI project configuration
├── .env                        # Generated Single Source of Truth for the ETL
├── bruin-pipeline1
│   ├── pipeline.yml            # ETL Pipeline definition and schedule
│   ├── shared
│   │   └── gcs_utils.py        # Shared Python utility for GCS streaming
│   ├── assets
│   │   ├── ingestion
│   │   │   └── ingest_kaggle_small.py    # Python script: Streams raw data to GCS
│   │   ├── staging
│   │   │   ├── convert_patterns_to_csv.py # Python script: Custom Patterns Parser
│   │   │   ├── create_external_tables.sql # DDL: GCS -> BigQuery linkage
│   │   │   ├── ref_small_attack_patterns.sql # Pattern descriptions reference
│   │   │   ├── stg_small_accounts.sql     # Account normalization
│   │   │   ├── stg_small_attacks.sql      # Bridge: Unique Trans to Attack Labels
│   │   │   ├── stg_small_patterns.sql     # Staged raw attack patterns
│   │   │   └── stg_small_trans.sql        # Trans cleaning, deduplication & Hashing
│   │   └── reports
│   │       └── all_transactions.sql      # Reports Layer (Partitioned/Clustered Table)
├── images
│   └── aml-pmg-dashboard.png      # Dashboard visual
├── keys
│   ├── aml-dash-8888-997342dff4de.json    # GCP Service Account Key
│   └── kaggle-api-key.json                # Kaggle API Credentials
├── scripts
│   └── setup.sh                           # Interactive environment builder
└── terraform
    ├── main.tf                            # IaC: GCP Bucket and BigQuery Dataset
    └── variables.tf                       # IaC: Dynamic Terraform variables
```

---

## Future Roadmap
* **Red Panda Integration:** I plan to integrate Red Panda to simulate real-time streaming, allowing the ETL to detect laundering patterns as transactions occur.
* **Monthly Batch Processing:** I am working on a 30-day automated trigger to ingest and process new financial transaction batches.
* **ML Pattern Training:** I intend to implement a machine learning training step that uses the orphan laundering records I discovered to automatically categorize and create new typologies.
* **Graph Database Integration:** I want to move from BigQuery to a dedicated graph database like Neo4j for deeper relationship analysis.
* **Walk-Through:** Creating a step-by-step guided demo for new users.