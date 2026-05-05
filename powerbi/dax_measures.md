# Power BI DAX Measures — Azure Pipeline Dashboard

---

## Page 1: Pipeline Health Monitor

### Daily Records Ingested
```dax
Records Ingested Today =
CALCULATE(
    SUM(pipeline_audit_log[records_out]),
    pipeline_audit_log[run_date] = TODAY()
)
```

### Pipeline Success Rate
```dax
Pipeline Success Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(pipeline_audit_log), pipeline_audit_log[status] = "SUCCESS"),
    COUNTROWS(pipeline_audit_log),
    0
) * 100
```

### Rejection Rate
```dax
Rejection Rate % =
DIVIDE(
    SUM(pipeline_audit_log[records_rejected]),
    SUM(pipeline_audit_log[records_in]),
    0
) * 100
```

### Avg Pipeline Duration (min)
```dax
Avg Pipeline Duration Min =
AVERAGE(pipeline_audit_log[duration_sec]) / 60
```

---

## Page 2: Executive Operations Summary

### Unified Throughput (all sources)
```dax
Unified Avg Throughput =
AVERAGE(fact_operations[throughput_uph])
```

### Cross-Source SLA Compliance
```dax
Unified SLA % =
DIVIDE(
    CALCULATE(COUNTROWS(fact_operations), fact_operations[sla_met] = TRUE()),
    COUNTROWS(fact_operations),
    0
) * 100
```

### Total Cost (all regions, all sources)
```dax
Total Cost =
SUMX(fact_operations, fact_operations[cost_per_unit] * fact_operations[units_processed])
```

---

## Page 5: Data Quality Scorecard

### Completeness Score
```dax
Data Completeness % =
100 - [Rejection Rate %]
```

### Timeliness (records loaded by 6 AM)
> Measures what % of daily pipeline runs completed before 6:00 AM target
```dax
On-Time Delivery % =
DIVIDE(
    CALCULATE(
        COUNTROWS(pipeline_audit_log),
        HOUR(pipeline_audit_log[run_timestamp]) < 6
    ),
    COUNTROWS(pipeline_audit_log),
    0
) * 100
```

### Quality Trend (30-day rolling rejection rate)
```dax
Rejection Rate 30D =
CALCULATE(
    [Rejection Rate %],
    DATESINPERIOD(pipeline_audit_log[run_date], LASTDATE(pipeline_audit_log[run_date]), -30, DAY)
)
```
