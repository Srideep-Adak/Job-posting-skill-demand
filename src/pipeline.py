"""Shared Spark transformations: identical business logic locally and on Databricks."""
from pyspark.sql import functions as F, Window

SOURCE_COLUMNS = {
    "companies": ["company_id", "company_name", "sector", "city"],
    "postings": ["posting_id", "company_id", "posted_date", "skills_raw"],
}


def bronze(spark, raw_root, save, cloud=False):
    result = {}
    for name, columns in SOURCE_COLUMNS.items():
        df = (spark.read.option("header", True).option("inferSchema", False)
              .option("ignoreLeadingWhiteSpace", False)
              .option("ignoreTrailingWhiteSpace", False).csv(
                  f"{raw_root}/{name}" if cloud else f"{raw_root}/{name}/part.csv"))
        if df.columns != columns:
            raise ValueError(f"Unexpected {name} header: {df.columns}")
        # Unity Catalog uses file metadata; local Apache Spark uses input_file_name.
        source = F.col("_metadata.file_path") if cloud else F.input_file_name()
        df = (df.withColumn("_source_file", source)
              .withColumn("_ingested_at", F.current_timestamp())
              .withColumn("_row_hash", F.sha2(F.to_json(F.struct(*columns),
                          options={"ignoreNullFields": "false"}), 256)))
        result[name] = save(f"bronze_{name}", df)
    return result


def silver(br, save):
    p = br["postings"]
    win = Window.partitionBy("posting_id").orderBy(F.desc("_ingested_at"), "_row_hash")
    ranked = p.withColumn("_rn", F.row_number().over(win))
    dupes = ranked.filter("_rn > 1").drop("_rn").withColumn("reject_reason", F.lit("duplicate_posting"))
    unique = ranked.filter("_rn = 1").drop("_rn")
    c = save("silver_companies", br["companies"].select(*SOURCE_COLUMNS["companies"]))
    known = c.select(F.col("company_id").alias("_known_company"))
    marked = (unique.join(known, unique.company_id == known._known_company, "left")
              .withColumn("_date", F.expr("try_cast(posted_date AS DATE)"))
              .withColumn("reject_reason",
                  F.when(F.col("skills_raw").isNull() | (F.trim("skills_raw") == "") |
                         (F.lower(F.trim("skills_raw")) == "not specified"), "no_skills_listed")
                   .when(F.col("_known_company").isNull(), "unknown_company")
                   .when(F.col("_date").isNull(), "unparseable_date")))
    rejected = marked.filter("reject_reason IS NOT NULL").select(*dupes.columns)
    rejects = save("silver_rejects", dupes.unionByName(rejected))
    accepted = (marked.filter("reject_reason IS NULL").drop("reject_reason", "_known_company", "posted_date")
                .withColumnRenamed("_date", "posted_date")
                .withColumn("month", F.trunc("posted_date", "month")))
    postings = save("silver_postings", accepted)
    tokens = (postings.select("posting_id", "company_id", "posted_date", "month",
                            F.explode(F.split("skills_raw", "[;,]")).alias("skill_raw")))
    skills = (tokens.withColumn("skill", F.lower(F.trim("skill_raw")))
              .filter("skill <> ''").dropDuplicates(["posting_id", "skill"])
              .join(c.select("company_id", "company_name", "sector", "city"), "company_id"))
    skills = save("silver_posting_skill", skills)
    return {"postings": postings, "skills": skills, "tokens": tokens, "rejects": rejects}


def gold(si, save):
    s = si["skills"]
    totals = si["postings"].groupBy("month").agg(F.count("*").alias("postings_that_month"))
    counts = s.groupBy("month", "skill").agg(F.countDistinct("posting_id").alias("postings_with_skill"))
    sm = (counts.join(totals, "month")
          .withColumn("skill_share", F.col("postings_with_skill") / F.col("postings_that_month"))
          .withColumn("rank_in_month", F.row_number().over(
              Window.partitionBy("month").orderBy(F.desc("postings_with_skill"), "skill"))))
    sm = save("gold_skill_month", sm.select("skill", "month", "postings_with_skill",
                     "postings_that_month", "skill_share", "rank_in_month"))
    a, b = s.select("posting_id", "month", "skill").alias("a"), s.select("posting_id", "month", "skill").alias("b")
    pair = (a.join(b, (F.col("a.posting_id") == F.col("b.posting_id")) &
                         (F.col("a.skill") != F.col("b.skill")))
            .select(F.col("a.month").alias("month"), F.col("a.skill").alias("skill_a"),
                    F.col("b.skill").alias("skill_b"))
            .groupBy("month", "skill_a", "skill_b").agg(F.count("*").alias("pair_postings")))
    ca = counts.select("month", F.col("skill").alias("skill_a"), F.col("postings_with_skill").alias("postings_a"))
    cb = counts.select("month", F.col("skill").alias("skill_b"), F.col("postings_with_skill").alias("postings_b"))
    pairs = (pair.join(ca, ["month", "skill_a"]).join(cb, ["month", "skill_b"]).join(totals, "month")
             .withColumn("confidence_a_to_b", F.col("pair_postings") / F.col("postings_a"))
             .withColumn("lift", F.col("pair_postings") * F.col("postings_that_month") /
                         (F.col("postings_a") * F.col("postings_b"))))
    pairs = save("gold_pair_month", pairs.select("skill_a", "skill_b", "month", "pair_postings",
                       "postings_a", "postings_b", "postings_that_month", "confidence_a_to_b", "lift"))
    return {"skill_month": sm, "pair_month": pairs}


def validate(spark, br, si, go):
    """Fail hard on structural errors; preserve discrepancies in the supplied brief."""
    checks = []
    def check(name, actual, expected, critical=True):
        passed = actual == expected
        checks.append(dict(check=name, actual=actual, expected=expected, passed=passed, critical=critical))
        print(f"{'PASS' if passed else 'FAIL'} {name}: {actual} (expected {expected})", flush=True)
    check("bronze_postings", br["postings"].count(), 55350)
    check("bronze_companies", br["companies"].count(), 400)
    check("silver_postings", si["postings"].count(), 51840)
    reasons = {r.reject_reason: r['count'] for r in si["rejects"].groupBy("reject_reason").count().collect()}
    for reason, n in [("duplicate_posting",1350),("no_skills_listed",1350),("unknown_company",540),("unparseable_date",270)]:
        check(reason, reasons.get(reason,0), n)
    check("row_reconciliation", si["postings"].count() + si["rejects"].count(), br["postings"].count())
    check("distinct_raw_skills", si["tokens"].select("skill_raw").distinct().count(), 57)
    check("canonical_skills", si["skills"].select("skill").distinct().count(), 20)
    check("invalid_clean_tokens", si["skills"].filter("skill <> lower(trim(skill)) OR skill LIKE '%,%' OR skill LIKE '%;%' OR skill = ''").count(),0)
    check("duplicate_posting_skill_keys", si["skills"].groupBy("posting_id","skill").count().filter("count > 1").count(),0)
    check("gold_skill_month", go["skill_month"].count(),360)
    check("gold_pair_month", go["pair_month"].count(),6660,False)
    check("monthly_denominators", sorted({r.postings_that_month for r in go["skill_month"].select("postings_that_month").distinct().collect()}), [2880])
    for skill, expected in [("snowflake",12726),("databricks",9954),("hadoop",9666),("dbt",6363)]:
        check(f"mentions_{skill}", si["skills"].filter(F.col("skill")==skill).count(),expected)
    for skill, first, last in [("snowflake",520,894),("databricks",400,706),("hadoop",860,214)]:
        rows = go["skill_month"].filter(F.col("skill")==skill).orderBy("month").collect()
        check(f"{skill}_first_last",[rows[0].postings_with_skill,rows[-1].postings_with_skill],[first,last])
    check("pair_bounds",go["pair_month"].filter("pair_postings > postings_a OR pair_postings > postings_b OR confidence_a_to_b > 1 OR lift < 0 OR skill_a = skill_b").count(),0)
    gp = go["pair_month"].groupBy("skill_a","skill_b").agg(F.sum("pair_postings").alias("n"),F.sum("postings_a").alias("d"))
    companions = gp.filter("skill_a = 'snowflake'").withColumn("confidence",F.col("n")/F.col("d")).orderBy(F.desc("confidence"),"skill_b").collect()
    check("snowflake_top_companion",companions[0].skill_b,"dbt",False)
    check("snowflake_dbt_confidence",next(r.confidence for r in companions if r.skill_b=="dbt"),0.5)
    check("other_companions_below_030",all(r.confidence<0.3 for r in companions if r.skill_b!="dbt"),True,False)
    failed = [c['check'] for c in checks if c['critical'] and not c['passed']]
    return checks, [r.asDict() for r in companions], failed
