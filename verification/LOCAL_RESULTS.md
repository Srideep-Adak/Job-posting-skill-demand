# Local feasibility results

Two complete executions succeeded. The second run took 129.01 seconds on local
Apache Spark 4.0.1. All 31 checks passed, including reconciliation against an
independent Python implementation. All three export hashes were identical to
the first run.

| Requirement | Expected | Actual |
|---|---:|---:|
| Input companies | 400 | 400 |
| Input postings | 55,350 | 55,350 |
| Accepted postings | 51,840 | 51,840 |
| Duplicate postings removed | 1,350 | 1,350 |
| Missing skill lists rejected | 1,350 | 1,350 |
| Unknown companies rejected | 540 | 540 |
| Invalid dates rejected | 270 | 270 |
| Raw distinct skill tokens | 57 | 57 |
| Canonical skills | 20 | 20 |
| Accepted postings per month | 2,880 | 2,880 |
| Skill-month rows | 360 | 360 |
| Directed skill-pair-month rows | 6,660 | 6,660 |

## Analytical outputs

The exported CSVs were reloaded into DuckDB and the supplied analysis SQL was
executed against them. Monthly top ten returned 180 rows, quarterly growth
returned 120 rows, and top three companion skills returned 60 rows. Companion
query results also matched independently computed results.

| Skill | January 2024 postings | June 2025 postings | Share change |
|---|---:|---:|---|
| Snowflake | 520 | 894 | 18.06% to 31.04% |
| Databricks | 400 | 706 | 13.89% to 24.51% |
| Hadoop | 860 | 214 | 29.86% to 7.43% |

dbt is Snowflake's strongest companion: 6,363 of the 12,726 postings mentioning
Snowflake also mention dbt, giving directional confidence of 50%. Every other
Snowflake companion has confidence below 30%.

These are properties of the PDF's synthetic dataset. They do not establish
real-world demand trends.

## Reproducibility and limits

`results/run_report.json` contains exact checks, timestamps and SHA-256 export
fingerprints. `results/previous_run_report.json` preserves the preceding run.
The original PDF generator required one Spark type correction, documented in
the project README and `original_generator_failure.log`.

These tests establish local transformation and analytical correctness. They do
not prove a Databricks scheduled trigger or Snowflake COPY behavior. See
`CLOUD_STATUS.md` for separately observed cloud execution.
