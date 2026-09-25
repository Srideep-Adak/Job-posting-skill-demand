# Proposed submission

**Project name:** Job Postings Skill Demand

**Brief description:** Build a Databricks and Snowflake data pipeline to analyze
technology skill demand in synthetic job postings. The project ingests raw data
into Bronze, removes duplicate and invalid postings and standardizes skill names
in Silver, and calculates monthly skill demand and skill co-occurrence in Gold.
Curated CSV exports are staged and loaded into Snowflake to identify the top ten
skills each month, quarter-on-quarter changes in skill share, and the top three
companion skills. Data-quality checks, repeatable loads and a scheduled Databricks
job support reliable and reproducible processing.

**Scope:** Topic 26 of the supplied brief; 18 months of generated postings,
January 2024 through June 2025. The dataset is synthetic, so findings describe
that dataset rather than the current real-world job market. The CSV handoff to
Snowflake is manual; the Databricks pipeline is the scheduled component.

**Feasibility evidence:** Two full local Spark runs pass all 31 checks, with an
independent reconciliation and identical export fingerprints. Databricks also
passed interactively and in an actual scheduled run (2m 42s). The actual cloud
exports were loaded into Snowflake, repeated loads added zero rows, and all 14
full-result checks passed. The topic is feasible within this stated scope.
See `verification/FINAL_VERIFICATION.md` for the execution evidence.
