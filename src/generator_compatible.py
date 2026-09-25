FL = ("'Python','SQL','Spark','Airflow','Kafka','Hive','AWS','Azure','GCP','Docker',"
      "'Kubernetes','Terraform','Scala','Java','PowerBI','Tableau'")
SEC = "'BFSI','IT Services','Product','Retail','Health','Telecom','Energy','Logistics'"
CTY = ("'Bengaluru','Hyderabad','Pune','Chennai','Mumbai','Delhi NCR','Noida',"
       "'Kolkata','Ahmedabad','Kochi'")
P = lambda x: f"element_at(array({FL}), cast(pmod({x}, 16) as int) + 1)"
def wr(d, p):  # both whitespace flags off, or the padded rows lose their spaces
    (d.write.mode('overwrite').option('header', True)
     .option('ignoreLeadingWhiteSpace', False)
     .option('ignoreTrailingWhiteSpace', False).csv(f'{VOL}/raw/{p}'))
wr(spark.range(400).selectExpr("format_string('CMP%03d', id) company_id",
    "format_string('Company %03d', id + 1) company_name",
    f"element_at(array({SEC}), cast(id div 50 as int) + 1) sector",
    f"element_at(array({CTY}), cast(pmod(id, 10) as int) + 1) city"), 'companies')
b = spark.range(54000).selectExpr("id", "cast(id div 3000 as int) m",
    "cast(pmod(id, 3000) as int) k")
b = b.selectExpr("id", "m", "k", "pmod((m*2700 + k)*7919, 48600) ak",
    f"concat(array_distinct(array({P('id')}, {P('id div 16')}, {P('id div 256')},"
    f" {P('id div 4096')})), if(k < 520 + 22*m, array('Snowflake'), array()),"
    " if(k >= 1000 and k < 1400 + 18*m, array('Databricks'), array()),"
    " if(k >= 1800 and k < 2660 - 38*m, array('Hadoop'), array()),"
    " if(k < 520 + 22*m and pmod(k, 2) = 0, array('dbt'), array())) a")
b = b.selectExpr("k", "format_string('JP%06d', id) posting_id",
    "if(k >= 2775 and k < 2805, 'CMP999',"
    " format_string('CMP%03d', pmod(id, 400))) company_id",
    "if(k >= 2805 and k < 2820, '0000-00-00', date_format(date_add(add_months("
    "date'2024-01-01', m), cast(pmod(id, 28) as int)), 'yyyy-MM-dd')) posted_date",
    "case when k >= 2700 and k < 2750 then ''"
    " when k >= 2750 and k < 2775 then 'Not specified'"
    " when k < 2700 and ak < 1000 then array_join(a, ',')"
    " when k < 2700 and ak < 3200 then upper(array_join(a, ';'))"
    " when k < 2700 and ak < 4900 then concat(' ', array_join(a, ' ; '), ' ')"
    " else array_join(a, ';') end skills_raw")
wr(b.unionByName(b.filter('k >= 2820 and k < 2895')).drop('k'), 'postings')
