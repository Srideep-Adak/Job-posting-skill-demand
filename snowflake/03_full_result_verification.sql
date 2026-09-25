USE SCHEMA CAPSTONE_23051560.SKILL_DEMAND;

CREATE OR REPLACE VIEW Q1_RESULTS AS
-- Q1: monthly top ten. Deterministic alphabetical tie-break.
SELECT skill, month, postings_with_skill, postings_that_month,
       ROUND(100.0 * skill_share, 2) AS share_pct, rank_in_month
FROM GOLD_SKILL_MONTH
QUALIFY ROW_NUMBER() OVER (PARTITION BY month ORDER BY postings_with_skill DESC, skill) <= 10
ORDER BY month, rank_in_month;

CREATE OR REPLACE VIEW Q2_RESULTS AS
-- Q2: quarter-on-quarter change in share, in percentage points.
-- The denominator is summed once per skill/month, never across all skills.
WITH q AS (
  SELECT skill, DATE_TRUNC('quarter', month) AS quarter,
         SUM(postings_with_skill) AS mentions,
         SUM(postings_that_month) AS postings,
         100.0 * CAST(SUM(postings_with_skill) AS DOUBLE) / NULLIF(SUM(postings_that_month), 0) AS share_pct
  FROM GOLD_SKILL_MONTH GROUP BY skill, DATE_TRUNC('quarter', month)
), growth AS (
  SELECT *, share_pct - LAG(share_pct) OVER (PARTITION BY skill ORDER BY quarter) AS change_pp
  FROM q
)
SELECT *, ROW_NUMBER() OVER (PARTITION BY quarter ORDER BY change_pp DESC, skill) AS growth_rank
FROM growth
ORDER BY quarter, growth_rank;

CREATE OR REPLACE VIEW Q3_RESULTS AS
-- Q3: top three companion skills from row-level Silver, matching PDF p107.
-- Confidence is directional: P(B|A) is different from P(A|B).
WITH s AS (SELECT DISTINCT posting_id, skill FROM SILVER_POSTING_SKILL),
     n AS (SELECT skill, COUNT(*) AS c FROM s GROUP BY skill),
     t AS (SELECT COUNT(DISTINCT posting_id) AS total FROM s),
     pairs AS (
SELECT a.skill AS skill_a, b.skill AS skill_b, COUNT(*) AS pair_postings,
       ROUND(COUNT(*) / NULLIF(MAX(na.c), 0), 6) AS confidence_a_to_b,
       ROUND(COUNT(*) * MAX(t.total) / NULLIF(MAX(na.c) * MAX(nb.c), 0), 6) AS lift
FROM s a JOIN s b ON a.posting_id = b.posting_id AND a.skill <> b.skill
JOIN n na ON na.skill = a.skill JOIN n nb ON nb.skill = b.skill CROSS JOIN t
GROUP BY a.skill, b.skill
)
SELECT * FROM pairs
QUALIFY ROW_NUMBER() OVER (PARTITION BY skill_a ORDER BY pair_postings DESC, skill_b) <= 3
ORDER BY skill_a, confidence_a_to_b DESC, skill_b;

CREATE OR REPLACE TABLE VERIFICATION_RESULTS (check_name VARCHAR, actual VARCHAR, expected VARCHAR, passed BOOLEAN);

INSERT INTO VERIFICATION_RESULTS SELECT 'GOLD_SKILL_MONTH_all_rows', h, '494d8b5cd03a9607a5ba733b87a78b1236e66e678270169aacedd2a0ad4322c8', h='494d8b5cd03a9607a5ba733b87a78b1236e66e678270169aacedd2a0ad4322c8' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(skill),'~NULL~'),COALESCE(TO_CHAR(month, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_VARCHAR(postings_with_skill),'~NULL~'),COALESCE(TO_VARCHAR(postings_that_month),'~NULL~'),COALESCE(TO_VARCHAR(rank_in_month),'~NULL~')),256),'') WITHIN GROUP (ORDER BY month,skill),256) h FROM GOLD_SKILL_MONTH);

INSERT INTO VERIFICATION_RESULTS SELECT 'GOLD_SKILL_MONTH_count', TO_VARCHAR(COUNT(*)), '360', COUNT(*)=360 FROM GOLD_SKILL_MONTH;

INSERT INTO VERIFICATION_RESULTS SELECT 'GOLD_PAIR_MONTH_all_rows', h, '21945b92f3f2def58b182685a78e218378c1e1144e9c93c81f24460c637ccd19', h='21945b92f3f2def58b182685a78e218378c1e1144e9c93c81f24460c637ccd19' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(skill_a),'~NULL~'),COALESCE(TO_VARCHAR(skill_b),'~NULL~'),COALESCE(TO_CHAR(month, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_VARCHAR(pair_postings),'~NULL~'),COALESCE(TO_VARCHAR(postings_a),'~NULL~'),COALESCE(TO_VARCHAR(postings_b),'~NULL~'),COALESCE(TO_VARCHAR(postings_that_month),'~NULL~')),256),'') WITHIN GROUP (ORDER BY month,skill_a,skill_b),256) h FROM GOLD_PAIR_MONTH);

INSERT INTO VERIFICATION_RESULTS SELECT 'GOLD_PAIR_MONTH_count', TO_VARCHAR(COUNT(*)), '6660', COUNT(*)=6660 FROM GOLD_PAIR_MONTH;

INSERT INTO VERIFICATION_RESULTS SELECT 'SILVER_POSTING_SKILL_all_rows', h, '34454ee902fda3e509754ba68105cd49e98f303667b1dbc81273af65a00297f2', h='34454ee902fda3e509754ba68105cd49e98f303667b1dbc81273af65a00297f2' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(posting_id),'~NULL~'),COALESCE(TO_VARCHAR(company_id),'~NULL~'),COALESCE(TO_CHAR(posted_date, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_CHAR(month, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_VARCHAR(skill),'~NULL~'),COALESCE(TO_VARCHAR(company_name),'~NULL~'),COALESCE(TO_VARCHAR(sector),'~NULL~'),COALESCE(TO_VARCHAR(city),'~NULL~')),256),'') WITHIN GROUP (ORDER BY posting_id,skill),256) h FROM SILVER_POSTING_SKILL);

INSERT INTO VERIFICATION_RESULTS SELECT 'SILVER_POSTING_SKILL_count', TO_VARCHAR(COUNT(*)), '227624', COUNT(*)=227624 FROM SILVER_POSTING_SKILL;

INSERT INTO VERIFICATION_RESULTS SELECT 'Q1_RESULTS_all_rows', h, '8142b2a5e5911a41115be57c55a0628cb8dc6e65b64af950891cac19357a2cff', h='8142b2a5e5911a41115be57c55a0628cb8dc6e65b64af950891cac19357a2cff' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(skill),'~NULL~'),COALESCE(TO_CHAR(month, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_VARCHAR(postings_with_skill),'~NULL~'),COALESCE(TO_VARCHAR(postings_that_month),'~NULL~'),COALESCE(TO_VARCHAR(CAST(ROUND(share_pct * 1000000) AS NUMBER(38,0))),'~NULL~'),COALESCE(TO_VARCHAR(rank_in_month),'~NULL~')),256),'') WITHIN GROUP (ORDER BY month,rank_in_month),256) h FROM Q1_RESULTS);

INSERT INTO VERIFICATION_RESULTS SELECT 'Q1_RESULTS_count', TO_VARCHAR(COUNT(*)), '180', COUNT(*)=180 FROM Q1_RESULTS;

INSERT INTO VERIFICATION_RESULTS SELECT 'Q2_RESULTS_all_rows', h, 'b1ca9644768496d00c06e2067e08600d3ccf50fa5f46b8bec07bc3e625292c24', h='b1ca9644768496d00c06e2067e08600d3ccf50fa5f46b8bec07bc3e625292c24' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(skill),'~NULL~'),COALESCE(TO_CHAR(quarter, 'YYYY-MM-DD'),'~NULL~'),COALESCE(TO_VARCHAR(mentions),'~NULL~'),COALESCE(TO_VARCHAR(postings),'~NULL~'),COALESCE(TO_VARCHAR(CAST(ROUND(share_pct * 1000000) AS NUMBER(38,0))),'~NULL~'),COALESCE(TO_VARCHAR(CAST(ROUND(change_pp * 1000000) AS NUMBER(38,0))),'~NULL~'),COALESCE(TO_VARCHAR(growth_rank),'~NULL~')),256),'') WITHIN GROUP (ORDER BY quarter,growth_rank),256) h FROM Q2_RESULTS);

INSERT INTO VERIFICATION_RESULTS SELECT 'Q2_RESULTS_count', TO_VARCHAR(COUNT(*)), '120', COUNT(*)=120 FROM Q2_RESULTS;

INSERT INTO VERIFICATION_RESULTS SELECT 'Q3_RESULTS_all_rows', h, '7bc9d9868dc04733c9908b1d0689d5048e1dc671e3408c17a7edb97edcb534f1', h='7bc9d9868dc04733c9908b1d0689d5048e1dc671e3408c17a7edb97edcb534f1' FROM (SELECT SHA2(LISTAGG(SHA2(CONCAT_WS('|',COALESCE(TO_VARCHAR(skill_a),'~NULL~'),COALESCE(TO_VARCHAR(skill_b),'~NULL~'),COALESCE(TO_VARCHAR(pair_postings),'~NULL~'),COALESCE(TO_VARCHAR(CAST(ROUND(confidence_a_to_b * 1000000) AS NUMBER(38,0))),'~NULL~'),COALESCE(TO_VARCHAR(CAST(ROUND(lift * 1000000) AS NUMBER(38,0))),'~NULL~')),256),'') WITHIN GROUP (ORDER BY skill_a,skill_b),256) h FROM Q3_RESULTS);

INSERT INTO VERIFICATION_RESULTS SELECT 'Q3_RESULTS_count', TO_VARCHAR(COUNT(*)), '60', COUNT(*)=60 FROM Q3_RESULTS;

INSERT INTO VERIFICATION_RESULTS SELECT 'skill_share_formula',TO_VARCHAR(COUNT(*)),'0',COUNT(*)=0 FROM GOLD_SKILL_MONTH WHERE skill_share IS NULL OR ABS(skill_share-postings_with_skill::DOUBLE/postings_that_month)>1e-12;

INSERT INTO VERIFICATION_RESULTS SELECT 'pair_formulas',TO_VARCHAR(COUNT(*)),'0',COUNT(*)=0 FROM GOLD_PAIR_MONTH WHERE confidence_a_to_b IS NULL OR lift IS NULL OR ABS(confidence_a_to_b-pair_postings::DOUBLE/postings_a)>1e-12 OR ABS(lift-pair_postings::DOUBLE*postings_that_month/(postings_a*postings_b))>1e-12;

SELECT check_name, passed FROM VERIFICATION_RESULTS ORDER BY check_name;