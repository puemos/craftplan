#!/usr/bin/env python3
"""Bottle order-report XLSX → 4 CSVs in a run directory.

Usage:
    python extract.py <xlsx_path> --from YYYY-MM-DD --to YYYY-MM-DD [--out DIR]

All Bottle dates are US/Eastern. We filter on `Fulfillment Slot Day` (date only).
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

GIFT_CARD_PIDS = {"PID-93974", "PID-93978", "PID-93979", "PID-93980"}
PID_RE = re.compile(r"^(.*) \(PID-([\d-]+)\)$")


def find_orders_sheet(xl: pd.ExcelFile) -> str:
    for name in xl.sheet_names:
        if name.startswith("Orders for "):
            return name
    raise SystemExit(f"No 'Orders for ...' sheet found. Sheets: {xl.sheet_names}")


def categorize(name: str, pid: str) -> str:
    n = name.lower()
    if pid in GIFT_CARD_PIDS or "gift card" in n:
        return "gift_card"
    if "combo box" in n or "cookie box" in n:
        return "kit"
    if "annuals" in n or "single origin" in n or n.strip() in {"destroyer", "climate project"}:
        return "resale_coffee"
    if "second story" in n and "honey" in n:
        return "resale_honey"
    return "manufactured"


def parse_name(full):
    if pd.isna(full):
        return ("", "", True)
    parts = str(full).strip().split()
    if len(parts) == 1:
        return ("", parts[0], True)
    return (parts[0], " ".join(parts[1:]), False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx_path")
    ap.add_argument("--from", dest="date_from", required=True)
    ap.add_argument("--to", dest="date_to", required=True)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    out = Path(args.out) if args.out else (
        Path(__file__).parent / "runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    out.mkdir(parents=True, exist_ok=True)

    xl = pd.ExcelFile(args.xlsx_path)
    sheet = find_orders_sheet(xl)
    df = pd.read_excel(xl, sheet_name=sheet, header=0)

    date_from = pd.Timestamp(args.date_from)
    date_to = pd.Timestamp(args.date_to)
    df = df[
        (df["Fulfillment Slot Day"] >= date_from)
        & (df["Fulfillment Slot Day"] <= date_to)
    ].copy()
    if df.empty:
        print(f"No rows in window {args.date_from}..{args.date_to}", file=sys.stderr)
        return 2

    prod_cols = [c for c in df.columns if isinstance(c, str) and PID_RE.match(c)]

    # ---- products.csv ----
    products = []
    for c in prod_cols:
        m = PID_RE.match(c)
        name = m.group(1).strip()
        pid = f"PID-{m.group(2)}"
        category = categorize(name, pid)
        if category == "gift_card":
            continue  # drop gift cards
        qty = int(df[c].fillna(0).sum())
        products.append({"pid": pid, "name": name, "category": category, "total_qty": qty})
    pd.DataFrame(products).sort_values(
        ["category", "total_qty"], ascending=[True, False]
    ).to_csv(out / "products.csv", index=False)

    kept_cols = {
        c for c in prod_cols
        if PID_RE.match(c) and f"PID-{PID_RE.match(c).group(2)}" not in GIFT_CARD_PIDS
        and categorize(PID_RE.match(c).group(1).strip(), f"PID-{PID_RE.match(c).group(2)}") != "gift_card"
    }

    # ---- customers.csv ----
    cust = df[[
        "Customer Name", "Email", "Phone", "Address1", "Address2",
        "City", "State", "Zip", "Number Of Times Customer Has Ordered",
    ]].copy()
    cust["Phone_norm"] = cust["Phone"].astype(str).str.replace(r"\D", "", regex=True)
    cust["key"] = cust["Phone_norm"].where(
        cust["Phone_norm"].str.len() >= 10,
        cust["Customer Name"].astype(str) + "|" + cust["Email"].astype(str),
    )
    cust_dedup = (
        cust.sort_values("Number Of Times Customer Has Ordered", ascending=False)
        .drop_duplicates("key", keep="first")
        .drop(columns=["Phone_norm", "key"])
    )
    names = cust_dedup["Customer Name"].apply(parse_name)
    cust_dedup["first_name"] = names.apply(lambda x: x[0])
    cust_dedup["last_name"] = names.apply(lambda x: x[1])
    cust_dedup["is_mononym"] = names.apply(lambda x: x[2])
    cust_dedup.to_csv(out / "customers.csv", index=False)

    # ---- orders.csv (headers only) ----
    header_cols = [c for c in df.columns if c not in prod_cols]
    df[header_cols].to_csv(out / "orders.csv", index=False)

    # ---- order_items.csv ----
    items = df.melt(
        id_vars=["Bottle ID"], value_vars=list(kept_cols),
        var_name="product_col", value_name="quantity",
    )
    items = items[items["quantity"].notna() & (items["quantity"] != 0)].copy()
    items["pid"] = "PID-" + items["product_col"].str.extract(r"\(PID-([\d-]+)\)$")[0]
    items["product_name"] = items["product_col"].str.replace(r" \(PID-[\d-]+\)$", "", regex=True).str.strip()
    items["quantity"] = items["quantity"].astype(int)
    items = items[["Bottle ID", "pid", "product_name", "quantity"]]
    items.to_csv(out / "order_items.csv", index=False)

    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
