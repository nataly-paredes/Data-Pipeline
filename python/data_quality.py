"""
data_quality.py
Shared data quality check functions used across all pipeline sources.
Logs rejections and returns a quality report dict.
"""

import pandas as pd
import os
import logging

log = logging.getLogger(__name__)

QUALITY_RULES = {
    "warehouse": {
        "required_columns": ["order_id", "order_date", "region", "shift",
                              "throughput_uph", "defect_rate_pct", "units_processed"],
        "non_null":         ["order_id", "order_date", "region"],
        "positive_numeric": ["throughput_uph", "units_processed"],
        "range_checks": {
            "defect_rate_pct":           (0, 100),
            "inventory_accuracy_pct":    (0, 100),
            "dock_delay_hrs":            (0, 48),
        }
    },
    "finance": {
        "required_columns": ["record_id", "month", "business_unit", "cost_center",
                              "amount", "record_type"],
        "non_null":         ["record_id", "month", "business_unit"],
        "positive_numeric": ["amount"],
        "range_checks": {}
    }
}


def run_quality_checks(path: str, source: str) -> dict:
    """
    Run quality checks for a given source file.
    Returns dict with records_in, records_out, records_rejected.
    """
    rules = QUALITY_RULES.get(source, {})
    df = pd.read_csv(path)
    records_in = len(df)
    rejection_flags = pd.Series(False, index=df.index)
    rejection_reasons = pd.Series("", index=df.index)

    # 1. Required columns
    missing_cols = [c for c in rules.get("required_columns", []) if c not in df.columns]
    if missing_cols:
        raise ValueError(f"Missing required columns: {missing_cols}")

    # 2. Non-null checks
    for col in rules.get("non_null", []):
        if col in df.columns:
            mask = df[col].isnull()
            rejection_flags |= mask
            rejection_reasons[mask] += f"null:{col} "

    # 3. Positive numeric
    for col in rules.get("positive_numeric", []):
        if col in df.columns:
            mask = pd.to_numeric(df[col], errors="coerce").fillna(-1) <= 0
            rejection_flags |= mask
            rejection_reasons[mask] += f"non_positive:{col} "

    # 4. Range checks
    for col, (lo, hi) in rules.get("range_checks", {}).items():
        if col in df.columns:
            vals = pd.to_numeric(df[col], errors="coerce")
            mask = (vals < lo) | (vals > hi)
            rejection_flags |= mask
            rejection_reasons[mask] += f"out_of_range:{col} "

    # Split passed / rejected
    df_pass = df[~rejection_flags].copy()
    df_fail = df[rejection_flags].copy()
    df_fail["rejection_reason"] = rejection_reasons[rejection_flags].str.strip()

    # Save rejections
    if len(df_fail) > 0:
        os.makedirs("../data/rejected", exist_ok=True)
        reject_path = path.replace("staging", "rejected").replace("_clean", "_rejected")
        df_fail.to_csv(reject_path, index=False)
        log.warning(f"  {len(df_fail)} records rejected → {reject_path}")

    # Overwrite clean file with only passing records
    df_pass.to_csv(path, index=False)

    records_rejected = len(df_fail)
    records_out = len(df_pass)
    rejection_rate = records_rejected / records_in * 100 if records_in > 0 else 0

    log.info(f"  Quality: {records_out}/{records_in} passed "
             f"({rejection_rate:.1f}% rejection rate)")

    return {
        "records_in":       records_in,
        "records_out":      records_out,
        "records_rejected": records_rejected,
        "rejection_rate":   rejection_rate,
    }
