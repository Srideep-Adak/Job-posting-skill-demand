-- Run in an existing usable warehouse. This script creates only this project's
-- database/schema/stage/tables; it does not replace or truncate existing objects.
CREATE DATABASE IF NOT EXISTS CAPSTONE_23051560;
CREATE SCHEMA IF NOT EXISTS CAPSTONE_23051560.SKILL_DEMAND;
USE SCHEMA CAPSTONE_23051560.SKILL_DEMAND;

CREATE FILE FORMAT IF NOT EXISTS SKILL_CSV TYPE=CSV SKIP_HEADER=1
  FIELD_OPTIONALLY_ENCLOSED_BY='"' EMPTY_FIELD_AS_NULL=TRUE
  NULL_IF=('') ERROR_ON_COLUMN_COUNT_MISMATCH=TRUE;
CREATE STAGE IF NOT EXISTS SKILL_DEMAND_STAGE FILE_FORMAT=SKILL_CSV;

CREATE TABLE IF NOT EXISTS GOLD_SKILL_MONTH (
  skill VARCHAR, month DATE, postings_with_skill NUMBER(38,0),
  postings_that_month NUMBER(38,0), skill_share DOUBLE, rank_in_month NUMBER(38,0)
);
CREATE TABLE IF NOT EXISTS GOLD_PAIR_MONTH (
  skill_a VARCHAR, skill_b VARCHAR, month DATE, pair_postings NUMBER(38,0),
  postings_a NUMBER(38,0), postings_b NUMBER(38,0), postings_that_month NUMBER(38,0),
  confidence_a_to_b DOUBLE, lift DOUBLE
);
CREATE TABLE IF NOT EXISTS SILVER_POSTING_SKILL (
  posting_id VARCHAR, company_id VARCHAR, posted_date DATE, month DATE,
  skill VARCHAR, company_name VARCHAR, sector VARCHAR, city VARCHAR
);

-- Upload the THREE exported CSVs into this named stage through Snowsight.
-- For true cross-platform evidence use the files downloaded from the Databricks
-- Volume. Local exports are also provided, but label their source honestly.
LIST @SKILL_DEMAND_STAGE;

-- First pass: a new table should load one file each. Save these result grids.
COPY INTO GOLD_SKILL_MONTH FROM @SKILL_DEMAND_STAGE
  FILES=('gold_skill_month.csv') ON_ERROR=ABORT_STATEMENT;
COPY INTO GOLD_PAIR_MONTH FROM @SKILL_DEMAND_STAGE
  FILES=('gold_pair_month.csv') ON_ERROR=ABORT_STATEMENT;
COPY INTO SILVER_POSTING_SKILL FROM @SKILL_DEMAND_STAGE
  FILES=('silver_posting_skill.csv') ON_ERROR=ABORT_STATEMENT;

-- Second pass: deliberately identical. Expect zero new files/rows.
-- Do not use FORCE=TRUE, TRUNCATE, or CREATE OR REPLACE between the passes.
COPY INTO GOLD_SKILL_MONTH FROM @SKILL_DEMAND_STAGE
  FILES=('gold_skill_month.csv') ON_ERROR=ABORT_STATEMENT;
COPY INTO GOLD_PAIR_MONTH FROM @SKILL_DEMAND_STAGE
  FILES=('gold_pair_month.csv') ON_ERROR=ABORT_STATEMENT;
COPY INTO SILVER_POSTING_SKILL FROM @SKILL_DEMAND_STAGE
  FILES=('silver_posting_skill.csv') ON_ERROR=ABORT_STATEMENT;

SELECT 'gold_skill_month' AS object_name, COUNT(*) AS rows, 360 AS expected FROM GOLD_SKILL_MONTH
UNION ALL SELECT 'gold_pair_month', COUNT(*), 6660 FROM GOLD_PAIR_MONTH
UNION ALL SELECT 'valid_postings', COUNT(DISTINCT posting_id), 51840 FROM SILVER_POSTING_SKILL
UNION ALL SELECT 'clean_skills', COUNT(DISTINCT skill), 20 FROM SILVER_POSTING_SKILL;

-- These queries must return zero rows.
SELECT skill, month, COUNT(*) FROM GOLD_SKILL_MONTH GROUP BY 1,2 HAVING COUNT(*) <> 1;
SELECT skill_a, skill_b, month, COUNT(*) FROM GOLD_PAIR_MONTH GROUP BY 1,2,3 HAVING COUNT(*) <> 1;
SELECT posting_id, skill, COUNT(*) FROM SILVER_POSTING_SKILL GROUP BY 1,2 HAVING COUNT(*) <> 1;

-- Reconcile Gold against the imported Silver, not just an expected constant.
WITH actual AS (
  SELECT skill, month, COUNT(*) n FROM SILVER_POSTING_SKILL GROUP BY 1,2
)
SELECT COALESCE(a.skill,g.skill) skill, COALESCE(a.month,g.month) month,
       a.n, g.postings_with_skill
FROM actual a FULL OUTER JOIN GOLD_SKILL_MONTH g ON a.skill=g.skill AND a.month=g.month
WHERE a.n IS NULL OR g.postings_with_skill IS NULL OR a.n <> g.postings_with_skill;

SELECT file_name, status, row_count, error_count, last_load_time
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME=>'CAPSTONE_23051560.SKILL_DEMAND.SILVER_POSTING_SKILL',
  START_TIME=>DATEADD('hour',-24,CURRENT_TIMESTAMP()))) ORDER BY last_load_time DESC;

-- Then execute 02_analysis.sql in the same database/schema and save its outputs.
