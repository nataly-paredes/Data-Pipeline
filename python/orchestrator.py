"""
orchestrator.py
Local pipeline runner that simulates the Azure Data Factory pipeline flow.
Runs all transformation steps in sequence with logging, timing, and error handling.
"""

import os
import time
import json
import logging
import pandas as pd
from datetime import datetime

from data_quality import run_quality_checks
from transform_warehouse import transform_warehouse
from transform_finance import transform_finance

# ── Logging Setup ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

PIPELINE_LOG = []


def log_step(step_name, status, records_in=0, records_out=0, records_rejected=0,
             duration_sec=0.0, error=None):
    entry = {
        "run_date":          datetime.now().strftime("%Y-%m-%d"),
        "run_timestamp":     datetime.now().isoformat(),
        "step":              step_name,
        "status":            status,
        "records_in":        records_in,
        "records_out":       records_out,
        "records_rejected":  records_rejected,
        "duration_sec":      round(duration_sec, 2),
        "error":             str(error) if error else None,
    }
    PIPELINE_LOG.append(entry)
    symbol = "✅" if status == "SUCCESS" else "❌"
    log.info(f"{symbol} [{step_name}] {status} | in={records_in} out={records_out} "
             f"rejected={records_rejected} ({duration_sec:.1f}s)")
    return entry


def run_step(name, fn, *args, **kwargs):
    """Wrap a transformation function with timing and error handling."""
    log.info(f"▶ Starting: {name}")
    start = time.time()
    try:
        result = fn(*args, **kwargs)
        duration = time.time() - start
        log_step(name, "SUCCESS",
                 records_in=result.get("records_in", 0),
                 records_out=result.get("records_out", 0),
                 records_rejected=result.get("records_rejected", 0),
                 duration_sec=duration)
        return result
    except Exception as e:
        duration = time.time() - start
        log_step(name, "FAILED", duration_sec=duration, error=e)
        log.error(f"   Error: {e}")
        raise


def save_pipeline_log():
    os.makedirs("../data/staging", exist_ok=True)
    df = pd.DataFrame(PIPELINE_LOG)
    path = f"../data/staging/pipeline_run_log_{datetime.now().strftime('%Y%m%d')}.csv"
    df.to_csv(path, index=False)
    log.info(f"📋 Pipeline log saved → {path}")
    return df


def print_summary(log_df):
    total_in  = log_df["records_in"].sum()
    total_out = log_df["records_out"].sum()
    total_rej = log_df["records_rejected"].sum()
    total_sec = log_df["duration_sec"].sum()
    failures  = (log_df["status"] == "FAILED").sum()

    print("\n" + "="*60)
    print("  PIPELINE SUMMARY")
    print("="*60)
    print(f"  Run date:          {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"  Total steps:       {len(log_df)}")
    print(f"  Failures:          {failures}")
    print(f"  Records ingested:  {total_in:,}")
    print(f"  Records output:    {total_out:,}")
    print(f"  Records rejected:  {total_rej:,} ({total_rej/max(total_in,1)*100:.1f}%)")
    print(f"  Total duration:    {total_sec:.1f}s")
    print("="*60 + "\n")


def main():
    log.info("🚀 Pipeline starting — simulating Azure Data Factory run")
    pipeline_start = time.time()

    # Step 1: Transform warehouse CSV source
    run_step("Transform: Warehouse CSV", transform_warehouse,
             input_path="../data/sources/warehouse_export.csv",
             output_path="../data/staging/warehouse_clean.csv",
             rejected_path="../data/rejected/warehouse_rejected.csv")

    # Step 2: Transform finance JSON source
    run_step("Transform: Finance JSON", transform_finance,
             input_path="../data/sources/finance_feed.json",
             output_path="../data/staging/finance_clean.csv",
             rejected_path="../data/rejected/finance_rejected.csv")

    # Step 3: Data quality checks across staging outputs
    run_step("Quality Check: Warehouse", run_quality_checks,
             path="../data/staging/warehouse_clean.csv",
             source="warehouse")

    run_step("Quality Check: Finance", run_quality_checks,
             path="../data/staging/finance_clean.csv",
             source="finance")

    # Step 4: Save pipeline log
    log_df = save_pipeline_log()
    total_duration = time.time() - pipeline_start
    print_summary(log_df)
    log.info(f"🏁 Pipeline complete in {total_duration:.1f}s")


if __name__ == "__main__":
    main()
