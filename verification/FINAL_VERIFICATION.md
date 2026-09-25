# Final feasibility verdict: PASS

Verified on 10 September 2026. **Job Postings Skill Demand (Topic 26) can be
finalized within the submitted scope.** The pipeline has been executed on both
Databricks and Snowflake, not only simulated locally.

## Results

| Stage | Observed result |
|---|---|
| Local Spark | Two complete runs; all 31 checks passed; identical exports |
| Independent oracle | Every posting-skill row, monthly count, pair count and rejection count agrees |
| Databricks pipeline | All 26 expectations passed; Bronze, Silver and Gold materialized as Delta tables |
| Databricks scheduler | Run 365017355708433 launched "By scheduler" and succeeded in 2m 42s |
| Cloud CSV export | 360 skill-month rows, 6,660 pair-month rows, 227,624 posting-skill rows |
| Cloud/local reconciliation | Every exported row agrees; numeric tolerance 1e-12 for floating measures |
| First Snowflake COPY | All three files LOADED, the expected row counts, zero errors |
| Repeated identical COPY | All three files LOAD_SKIPPED, zero rows loaded; reason "File was loaded before." |
| Snowflake complete-data checks | All three imported tables match independent row fingerprints and counts |
| Monthly top ten | All 180 output rows match expected results |
| Quarterly growth | All 120 output rows match after making division precision explicit |
| Top three companions | All 60 output rows match expected results |
| Snowflake final verdict | **14 checks, 14 passed, 0 failed** |

All 51,840 valid postings are represented in the Silver data. Duplicate and
invalid records were removed before skill expansion; 57 raw skill variants
normalize to 20 canonical skills. The expected Snowflake/Databricks growth,
Hadoop decline and 50% Snowflake-to-dbt companion confidence were verified.

## Reproducible evidence

- Databricks notebook: `1554045562250545`.
- Databricks job: `896932159262554`; scheduled run: `365017355708433`.
- Snowflake account location is intentionally omitted from this public repository.
- Snowflake schema: `CAPSTONE_23051560.SKILL_DEMAND`.
- `COPY_AUDIT` preserves the six actual COPY responses from the first/repeat test.
- `VERIFICATION_RESULTS` stores each check's actual and expected values and pass flag.
- `Q1_RESULTS`, `Q2_RESULTS`, `Q3_RESULTS` retain the analytical queries as views.
- `snowflake/03_full_result_verification.sql` reproduces the 14 verification checks.
- `cloud_exports/`, `cloud_export_reconciliation.json` and
  `expected_cloud_fingerprints.json` retain the actual transfer files and expected fingerprints.

Full-result fingerprints use SHA-256 over ordered row hashes. Exact text, dates,
identifiers, counts and ranks are included. Analytical decimal measures are
normalized to six decimal places; Gold floating formulas are checked to 1e-12.
Snowflake's results-download link was blocked by Chrome, so the final results
were inspected in the live SQL result grid and retained in database tables.

## Corrections proven during testing

1. The PDF generator's date offset needs an INT cast in Spark 4; the original is preserved.
2. The companion query ranks a grouped CTE to avoid Databricks' aggregate/window error.
3. Quarterly percentage calculations cast summed mentions to DOUBLE, avoiding
   engine-specific decimal division rounding. All 120 local results remain unchanged.

These corrections preserve the topic, generated data and intended calculations.

## Scope of this verdict

This is a reproducible analysis of the brief's synthetic dataset. Databricks
processing is schedulable; the demonstrated CSV handoff to Snowflake is manual.
It does not claim live job scraping, real-world demand prediction or unattended
cross-platform integration. The single test schedule has no future occurrences.
Final academic submission still needs any presentation/report formatting required
by the course; those requirements do not change the proven technical feasibility.
