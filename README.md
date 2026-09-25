# Job Postings Skill Demand

## Project Information

**Project:** Job Postings Skill Demand Analysis\
**Student Name:** Srideep Adak\
**Roll Number:** 23051631\
**Technology Stack:** Databricks, Apache Spark, PySpark, Snowflake,
Python, SQL\
**Dataset:** Synthetic job-postings dataset

------------------------------------------------------------------------

## Project Overview

This project develops an end-to-end **Databricks and Snowflake data
pipeline** for analyzing technology skill demand in synthetic job
postings.

The pipeline generates job-posting data, processes it through **Bronze,
Silver, and Gold data layers**, performs data-quality checks, exports
curated datasets, and loads the results into Snowflake for analytical
queries.

The project focuses on three main business questions:

1.  What are the **top 10 skills by posting count for each month**?
2.  Which skills are **growing fastest quarter over quarter**?
3.  Which skills **frequently appear together** in the same job posting?

------------------------------------------------------------------------

## Problem Statement

A training organization needs to understand which technology skills are
appearing most frequently in job postings so that its curriculum can be
aligned with current skill demand.

The source data is synthetic and contains deliberately messy records,
including:

-   Duplicate job postings
-   Missing or empty skills
-   `"Not specified"` skills
-   Unknown company IDs
-   Invalid dates
-   Different spellings and capitalization of the same skill
-   Extra spaces and inconsistent separators

The pipeline cleans and standardizes this data before producing reliable
analytical outputs.

------------------------------------------------------------------------

## Data Pipeline Architecture

``` text
Synthetic Job Postings
        |
        v
   Bronze Layer
        |
        | Raw data ingestion
        v
    Silver Layer
        |
        | Deduplication
        | Skill splitting
        | Skill normalization
        | Data-quality filtering
        v
     Gold Layer
        |
        | Monthly skill demand
        | Quarterly skill trends
        | Skill co-occurrence
        v
   CSV Exports
        |
        v
    Snowflake
        |
        | SQL Analysis
        v
   Final Insights
```

------------------------------------------------------------------------

## Bronze Layer

The Bronze layer stores the generated job-posting data with minimal
transformation.

The pipeline preserves the original skill strings so that the raw data
remains available for validation and comparison.

The generated dataset contains:

-   **54,000 valid target postings**
-   Additional deliberately malformed and duplicate records used for
    data-quality validation
-   Company, sector, city, skill, and posting-date information

------------------------------------------------------------------------

## Silver Layer

The Silver layer prepares the data for analysis.

### Main transformations

1.  **Deduplication**\
    Duplicate postings are identified and removed before skill
    processing.

2.  **Skill splitting**\
    Skills are split using the required character-class separator logic
    rather than a simple delimiter split.

3.  **Skill normalization**\
    Skill names are standardized by trimming spaces, removing unwanted
    punctuation, and normalizing capitalization.

4.  **Data-quality filtering**\
    Invalid records are rejected with reasons such as:

    -   `no_skills_listed`
    -   `not_specified`
    -   `unknown_company`
    -   `unparseable_date`

5.  **Validation**\
    The Silver layer is checked against the expected row counts and
    data-quality conditions.

------------------------------------------------------------------------

## Gold Layer

The Gold layer contains curated analytical datasets.

### Skill-Month

Contains monthly skill-demand information, including:

-   Skill
-   Month
-   Number of postings with the skill
-   Total postings in the month
-   Skill share
-   Monthly rank

### Skill Pairs

Contains skill co-occurrence information, including:

-   Skill A
-   Skill B
-   Month
-   Number of postings containing both skills
-   Confidence
-   Lift

These outputs support monthly demand analysis, quarter-over-quarter
comparisons, and skill-combination analysis.

------------------------------------------------------------------------

## Snowflake Analysis

The curated Gold-layer CSV files are loaded into Snowflake.

Snowflake is used to answer the final analytical questions:

### 1. Top 10 skills by month

Identifies the ten most frequently occurring skills for every month in
the dataset.

### 2. Fastest-growing skills

Compares skill share across quarters to identify changes in demand over
time.

### 3. Skill combinations

Uses pair counts, confidence, and lift to identify skills that commonly
occur together in job postings.

------------------------------------------------------------------------

## Data Quality and Verification

The project includes validation at multiple stages.

Important checks include:

  Check                                Result
  ------------------------------- -----------
  Generated input rows                 55,350
  Valid postings after cleaning        51,840
  Duplicate rows removed                1,350
  Canonical skills                         20
  Raw skill variants                       57
  Skill-month rows                        360
  Pair-month rows                       6,660
  Snowflake verification checks     14 passed

The pipeline also verifies that repeated Snowflake loads do not create
duplicate records.

------------------------------------------------------------------------

## Repository Structure

``` text
Job-posting-skill-demand/
│
├── databricks/
│   ├── Databricks notebook
│   └── Notebook builder
│
├── docs/
│   └── index.html              # Project dashboard
│
├── exports/
│   └── Gold-layer CSV outputs
│
├── snowflake/
│   ├── Setup and load SQL
│   ├── Analysis SQL
│   └── Verification SQL
│
├── src/
│   ├── Synthetic-data generator
│   └── Spark transformation pipeline
│
├── verification/
│   ├── Validation scripts
│   ├── Expected results
│   └── Verification reports
│
├── PROJECT_BRIEF.md
├── SUBMISSION_DETAILS.md
├── README.md
└── LICENSE
```

------------------------------------------------------------------------

## Running the Project Locally

### Requirements

-   Python 3.11+
-   Java/JDK compatible with the Spark setup
-   PySpark 4.0.1
-   DuckDB

Run the local verification pipeline:

``` powershell
python verification/run_local.py
```

Running the pipeline more than once can be used to verify deterministic
outputs and export fingerprints.

------------------------------------------------------------------------

## Running on Databricks

1.  Import the project notebook from the `databricks/` directory.
2.  Run the notebook in a Databricks environment.
3.  Verify the Bronze, Silver, and Gold processing steps.
4.  Download the generated Gold-layer CSV exports.
5.  Compare the outputs with the expected verification results.

The Databricks workflow is designed to be schedulable.

------------------------------------------------------------------------

## Loading Data into Snowflake

After generating the Gold-layer CSV files:

1.  Set up the Snowflake objects using the SQL scripts in `snowflake/`.
2.  Upload the CSV files to the configured stage.
3.  Execute the `COPY INTO` load.
4.  Run the analytical SQL queries.
5.  Run the verification SQL to confirm the expected results.

The tested CSV transfer from Databricks to Snowflake is a documented
manual handoff.

------------------------------------------------------------------------

## Dashboard

A static project dashboard is available in the `docs/` directory.

The dashboard can be hosted using **GitHub Pages** with:

``` text
Source: Deploy from a branch
Branch: main
Folder: /docs
```

Live dashboard:

**https://srideep-adak.github.io/Job-posting-skill-demand/**

------------------------------------------------------------------------

## Key Technologies

-   **Python** --- Data generation and pipeline logic
-   **PySpark / Apache Spark** --- Large-scale data transformation
-   **Databricks** --- Cloud data processing and scheduled execution
-   **Snowflake** --- Data warehousing and analytical SQL
-   **SQL** --- Data loading, analysis, and validation
-   **GitHub** --- Version control and project documentation
-   **GitHub Pages** --- Static project dashboard hosting

------------------------------------------------------------------------

## Project Scope

This project uses a **fixed synthetic dataset** covering **January 2024
through June 2025**.

The project is intended to demonstrate a reproducible data-engineering
workflow for skill-demand analysis. It does not scrape live job
listings, make labour-market predictions, or claim unattended
Databricks-to-Snowflake integration.

------------------------------------------------------------------------

## Author

**Srideep Adak**\
**Roll Number:** 23051631

GitHub: **Srideep-Adak**

------------------------------------------------------------------------

## License

This project is provided for educational and academic purposes.
