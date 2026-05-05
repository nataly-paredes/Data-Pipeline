# ☁️ End-to-End Data Pipeline + BI Layer
### Raw Data → Azure Data Factory → SQL → Power BI | Azure + SQL + Power BI

---

## 📖 The Business Story

Operations teams across multiple warehouse sites were generating data in silos — each location used a different system, exported in different formats, on different schedules. Leadership had **no single source of truth**, and analysts were spending 15+ hours a week manually consolidating files just to build reports.

As the BI Engineer on this project, I designed and implemented an end-to-end pipeline that:
1. Ingested raw data from multiple source formats (CSV, JSON, simulated API)
2. Applied standardized transformations and data quality checks in a staging layer
3. Loaded clean, modeled data into a SQL analytics layer
4. Surfaced an executive Power BI dashboard on top — automatically refreshed

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                             │
│   CSV Exports    JSON Feeds    Simulated API    Excel Uploads   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│               AZURE DATA FACTORY (Orchestration)                │
│   • Ingest pipelines (Copy Activity per source type)           │
│   • Trigger: Daily 2:00 AM UTC                                 │
│   • Error handling + retry logic                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AZURE DATA LAKE (Raw Zone)                   │
│   raw/warehouse/YYYY/MM/DD/                                    │
│   raw/finance/YYYY/MM/DD/                                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│            PYTHON TRANSFORMATION LAYER (Staging)               │
│   • Schema normalization                                       │
│   • Data quality checks + rejection logging                    │
│   • Business rule application                                  │
│   • Output to Parquet (compressed, partitioned)               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              SQL SERVER (Analytics / Serving Layer)            │
│   • Star schema: fact_operations + dimension tables            │
│   • Stored procedures for incremental loads                    │
│   • Indexed views for Power BI performance                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    POWER BI (BI Layer)                          │
│   • DirectQuery / Import hybrid                                │
│   • Scheduled refresh aligned to pipeline completion           │
│   • Row-level security by region                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
project3-azure-pipeline/
│
├── data/
│   ├── sources/
│   │   ├── warehouse_export.csv              # Source 1: CSV
│   │   ├── finance_feed.json                 # Source 2: JSON
│   │   └── api_response_sample.json          # Source 3: Simulated API
│   ├── staging/                              # Transformed output
│   └── rejected/                            # Failed quality checks
│
├── pipeline/
│   ├── adf_pipeline_definition.json          # ADF pipeline JSON (deployable)
│   └── adf_linked_services.json             # Linked service templates
│
├── python/
│   ├── generate_source_data.py              # Generate mock multi-source data
│   ├── transform_warehouse.py               # Transform CSV source
│   ├── transform_finance.py                 # Transform JSON source
│   ├── data_quality.py                      # Shared quality check functions
│   └── orchestrator.py                      # Local pipeline runner (simulates ADF)
│
├── sql/
│   ├── 01_create_star_schema.sql            # Fact + dimension tables
│   ├── 02_stored_proc_incremental_load.sql  # Incremental upsert logic
│   ├── 03_indexed_views.sql                 # Performance views for Power BI
│   └── 04_data_lineage_log.sql             # Pipeline audit/lineage table
│
├── powerbi/
│   ├── dax_measures.md
│   └── rls_setup.md                        # Row-level security documentation
│
└── README.md
```

---

## 🛠️ Tools & Technologies

- **Azure Data Factory** — orchestration, scheduling, copy activities
- **Azure Data Lake Storage Gen2** — raw file landing zone
- **Python (pandas, pyarrow)** — transformation, quality checks, Parquet output
- **SQL Server** — star schema, stored procedures, indexed views
- **Power BI + DAX** — executive dashboard, RLS, scheduled refresh

---

## 📊 Dashboard Pages

1. **Pipeline Health Monitor** — daily run status, records ingested, rejection rate
2. **Executive Operations Summary** — unified KPIs across all source systems
3. **Data Lineage View** — which records came from which source on which date
4. **Regional Performance** — cross-source regional comparison
5. **Data Quality Scorecard** — accuracy, completeness, timeliness by source

---

## 🔑 Key DAX Measures

See [`powerbi/dax_measures.md`](powerbi/dax_measures.md) for full documentation.

---

## 📈 Key Outcomes (Simulated)

- Eliminated **15+ hours/week** of manual data consolidation
- Pipeline runs in **under 12 minutes** end-to-end for ~50K daily records
- Data rejection rate reduced from **8.3% → 0.9%** after quality rules implemented
- Power BI dashboard auto-refreshes by **6:00 AM daily**, ready for morning standup

---

## 🚀 How to Run Locally

```bash
# 1. Generate mock source data
python python/generate_source_data.py

# 2. Run full local pipeline (simulates ADF flow)
python python/orchestrator.py

# 3. Load staging output to SQL
#    Run sql/01 → 02 → 03 → 04 in order

# 4. Open Power BI and connect to SQL Server or staging CSVs
```

### Deploy to Azure (outline)
```bash
# 1. Create Azure Resource Group + Data Factory instance
# 2. Import pipeline/adf_pipeline_definition.json via ADF Studio
# 3. Update linked service credentials in adf_linked_services.json
# 4. Set trigger schedule (daily 2:00 AM UTC)
# 5. Connect Power BI to Azure SQL via gateway
```

---

*This project uses fully synthetic data generated for portfolio demonstration purposes.*
