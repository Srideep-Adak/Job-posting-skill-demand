# Job Postings Skill Demand

**Topic 26 - Capstone Project Briefs, pages 104-107**  
**Student ID:** 23051560

This project is a working Databricks and Snowflake pipeline for analyzing technology skill demand in a **synthetic** job-postings dataset. It generates raw data, applies Bronze/Silver/Gold transformations, exports curated CSV files, loads them into Snowflake, and validates three analytical outputs.

The live project evidence passed end to end: two complete local Spark runs passed 31 checks; Databricks passed 26 notebook expectations and a scheduled run; cloud exports reconciled with local data; Snowflake loaded all files, skipped a repeat load safely, and passed 14 of 14 full-result checks.

## Dashboard

The static dashboard is in [`docs/`](docs/). It has no credentials or build step. Open `docs/index.html` through a static host, or enable GitHub Pages from the `main` branch and `/docs` folder.

## Project brief

Build a Databricks and Snowflake data pipeline to analyze technology skill demand in synthetic job postings. The project ingests raw data into Bronze, removes duplicate and invalid postings and standardizes skill names in Silver, and calculates monthly demand and skill co-occurrence in Gold. Curated CSV exports are staged and loaded into Snowflake to identify the top ten skills each month, quarter-on-quarter changes in skill share, and the top three companion skills. Data-quality checks, repeatable loads and a scheduled Databricks job support reliable and reproducible processing.

## Repository layout

| Folder | Contents |
| --- | --- |
| `src/` | Synthetic-data generator and Spark transformation pipeline. |
| `databricks/` | Self-contained Databricks notebook and notebook builder. |
| `snowflake/` | Setup, `COPY INTO`, analytical query and full-result verification SQL. |
| `exports/` | Compact Gold layer CSV outputs used for inspection and dashboard provenance. |
| `verification/` | Local result reports, expected query results and final evidence summary. |
| `docs/` | Responsive hosted dashboard source. |
| `report/` | Final capstone report PDF. |

## Run the pipeline locally

Requirements: Python 3.11+, a Spark-compatible JDK, PySpark 4.0.1 and DuckDB.

```powershell
python verification/run_local.py
```

Run the command twice to compare deterministic export fingerprints. The original PDF generator is kept in `src/generator.py`; `src/generator_compatible.py` applies the Spark 4-compatible integer date-offset cast used for the verified run.

## Run on Databricks and Snowflake

1. Import `databricks/23051560_Job_Postings_Skill_Demand.ipynb` and run all cells on a Databricks serverless environment.
2. Download the three CSV exports produced by the notebook.
3. In Snowflake, run `snowflake/01_setup_load_verify.sql`, upload the CSV files to the named stage, and execute the load sections.
4. Run `snowflake/02_analysis.sql` and `snowflake/03_full_result_verification.sql`.
5. Compare outputs with the expected result CSVs in `verification/results/`.

The Databricks part of the project is schedulable. The tested CSV handoff to Snowflake is manual and is documented as such.

## Verification summary

| Check | Verified result |
| --- | --- |
| Valid postings | 51,840 from 55,350 generated inputs |
| Canonical skills | 20 from 57 raw variants |
| Databricks scheduled run | Succeeded in 2 minutes 42 seconds |
| Cloud curated outputs | 360 skill-month and 6,660 pair-month rows reconciled |
| Snowflake first load | 360, 6,660 and 227,624 rows; zero errors |
| Repeat load | All files `LOAD_SKIPPED`; zero duplicate rows |
| Snowflake verification | 14 passed, 0 failed |

See [`verification/FINAL_VERIFICATION.md`](verification/FINAL_VERIFICATION.md) for the complete scope and evidence.

## Scope statement

All conclusions in this repository describe a fixed synthetic dataset covering January 2024 through June 2025. The project does not scrape live job listings, make labour-market predictions, or claim unattended Databricks-to-Snowflake integration.
