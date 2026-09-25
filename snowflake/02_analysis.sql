-- Q1: monthly top ten. Deterministic alphabetical tie-break.
SELECT skill, month, postings_with_skill, postings_that_month,
       ROUND(100.0 * skill_share, 2) AS share_pct, rank_in_month
FROM GOLD_SKILL_MONTH
QUALIFY ROW_NUMBER() OVER (PARTITION BY month ORDER BY postings_with_skill DESC, skill) <= 10
ORDER BY month, rank_in_month;

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
