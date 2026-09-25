"""Package shared tested source in a self-contained importable Databricks notebook."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
def cell(kind,text):
    return dict(cell_type=kind,metadata={},source=text.splitlines(True),**(
        dict(outputs=[],execution_count=None) if kind=='code' else {}))

setup='''import json, re, hashlib
from datetime import datetime, timezone
from pyspark.sql import functions as F
MY_ID = "23051560"
assert re.fullmatch(r"[A-Za-z0-9_]+", MY_ID)
SCHEMA = f"workspace.capstone_{MY_ID}"
PREFIX = f"sd_{MY_ID}_"
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
spark.sql(f"CREATE VOLUME IF NOT EXISTS {SCHEMA}.raw")
VOL = f"/Volumes/workspace/capstone_{MY_ID}/raw"
spark.conf.set("spark.sql.ansi.enabled", "true")
spark.conf.set("spark.sql.session.timeZone", "UTC")
def save(name, df):
    target = f"{SCHEMA}.{PREFIX}{name}"
    df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(target)
    result = spark.table(target)
    print(name, result.count())
    return result
'''
run='''br = bronze(spark, f"{VOL}/raw", save, cloud=True)
si = silver(br, save)
go = gold(si, save)
checks, companions, failures = validate(spark, br, si, go)
report = {"timestamp_utc": datetime.now(timezone.utc).isoformat(),
          "checks": checks, "companions": companions, "critical_failures": failures}
save("validation_results", spark.createDataFrame([(c["check"], str(c["actual"]), str(c["expected"]),
         c["passed"], c["critical"]) for c in checks],
         "check string, actual string, expected string, passed boolean, critical boolean"))
assert not failures, f"Pipeline correctness checks failed: {failures}"
print("CORE PIPELINE VALIDATED")
display(spark.table(f"{SCHEMA}.{PREFIX}validation_results"))
'''
export='''# One header-bearing CSV per table; preserve the Silver table required by Q3.
exports = {
    "gold_skill_month": go["skill_month"].orderBy("month", "skill"),
    "gold_pair_month": go["pair_month"].orderBy("month", "skill_a", "skill_b"),
    "silver_posting_skill": si["skills"].select("posting_id", "company_id", "posted_date", "month",
             "skill", "company_name", "sector", "city").orderBy("posting_id", "skill"),
}
for name, df in exports.items():
    folder = f"{VOL}/exports/{name}_parts"
    df.coalesce(1).write.mode("overwrite").option("header", True).csv(folder)
    parts = [x.path for x in dbutils.fs.ls(folder) if x.name.startswith("part-") and x.name.endswith(".csv")]
    assert len(parts) == 1, parts
    # Copy within this project's volume; no driver collection of the Silver export.
    destination = f"{VOL}/exports/{name}.csv"
    # Hadoop copy with overwrite scoped to this exact generated output.
    import shutil
    shutil.copyfile(parts[0].replace("dbfs:", ""), destination)
    with open(destination, "rb") as f:
        checksum = hashlib.file_digest(f, "sha256").hexdigest()
    print("EXPORT", destination, df.count(), checksum)
with open(f"{VOL}/exports/cloud_validation.json", "w") as f:
    json.dump(report, f, indent=2, default=str)
print("DATABRICKS PIPELINE AND EXPORT COMPLETE")
'''
cells=[cell('markdown', '''# Job Postings Skill Demand — Topic 26
Synthetic data, January 2024–June 2025. This is not a live labour-market study.
The PDF generator is preserved in the source package. The executed version changes only
the `date_add` day-offset type to INT because Spark rejects BIGINT.
All business transformations below are generated from the same source tested locally.
Named tables and raw files are scoped to this capstone. Reruns replace this snapshot.
'''),cell('code',setup),cell('markdown','## 1. Generate the specified source data'),
cell('code',(ROOT/'src/generator_compatible.py').read_text()),
cell('markdown','## 2. Shared Bronze, Silver, Gold and verification logic'),
cell('code',(ROOT/'src/pipeline.py').read_text()),cell('code',run),
cell('markdown','## 3. Export to the Volume for Snowflake staging'),cell('code',export)]
for label,query in zip(['Monthly top ten','Quarterly growth','Companion skills'],
                     (ROOT/'snowflake/02_analysis.sql').read_text().split(';')):
    query=query.strip()
    if not query: continue
    cells.append(cell('markdown',f'## {label}\nThe authoritative cross-platform queries are in `snowflake/02_analysis.sql`.'))
    # QUALIFY is supported in Databricks SQL. Reference the namespaced Delta tables.
    for name in ['GOLD_SKILL_MONTH','GOLD_PAIR_MONTH','SILVER_POSTING_SKILL']:
        query=query.replace(name,'{SCHEMA}.{PREFIX}'+name.lower())
    cells.append(cell('code','display(spark.sql(f'+repr(query)+'))\n'))
nb=dict(cells=cells,metadata={'kernelspec':{'display_name':'Python 3','language':'python','name':'python3'}},nbformat=4,nbformat_minor=5)
path=ROOT/'databricks/23051560_Job_Postings_Skill_Demand.ipynb'
path.write_text(json.dumps(nb,indent=2),encoding='utf-8')
for c in cells:
    if c['cell_type']=='code': compile(''.join(c['source']),str(path),'exec')
print(path)
