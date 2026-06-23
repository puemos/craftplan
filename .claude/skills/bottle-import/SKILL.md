---
name: bottle-import
description: Import a Bottle order-report XLSX (orders from the breadparavion.com e-commerce platform) into Craftplan as Customers, Products, Orders, and OrderItems. Triggers on phrases like "import this Bottle order report", "import Bottle orders", "load Bottle XLSX", or when the user @-references an XLSX whose filename contains "Bottles" or whose first 'Orders for ...' sheet matches the Bottle export shape. Idempotent — safe to re-run.
---

# Bottle order-report → Craftplan importer

This skill ingests a Bottle XLSX into Craftplan in two stages: a Python extractor produces 4 inspectable CSVs, then a Mix task ingests them with a preview gate and an audit log. Craftplan is the source of truth for `Product` data; `price_map.yml` is only consulted for unknown PIDs during the bootstrap.

## Inputs

- `xlsx_path` — absolute path to a Bottle XLSX export.
- `date_from` — `YYYY-MM-DD` start of the fulfillment window.
- `date_to` — `YYYY-MM-DD` end of the fulfillment window.

## Prerequisites

- **Elixir version**: This project pins Elixir 1.18.3. Verify your local version matches, or run `mise install` (if using mise) before running `mix` commands.

## Procedure

Follow in order. Do not skip the gates.

### 1. Stage 1 — extract

```bash
cd /Users/timchambers/Sites/craftplan/priv/imports/bottle
# Python venv with pandas + openpyxl
source .venv/bin/activate
python extract.py "<xlsx_path>" --from <date_from> --to <date_to>
```

The script prints the run-directory path on its last stdout line. Capture it.

### 2. Verify the extract

```bash
wc -l <run_dir>/*.csv
```

Confirm row counts look sensible. If `orders.csv` has zero rows in the window, halt — usually means the wrong date range.

### 3. Preview gate

```bash
mix bottle.import <run_dir> --price-map priv/imports/bottle/price_map.yml
```

The task prints a preview block. Inspect it for:
- **Unknown PIDs** — if any, the task will abort with a list. Either (a) create those Products in Craftplan via Manage → Products, then re-run; or (b) add the PID + price to `priv/imports/bottle/price_map.yml`.
- **Inserts vs skips** — first run should show ~0 skips. Re-runs after partial success should show non-zero skips.

Type `y` to proceed, anything else to abort.

### 4. Verify post-import

```bash
mix bottle.import <run_dir> --yes --price-map priv/imports/bottle/price_map.yml
# Should report 0 inserted, N skipped — idempotency check.
```

### 5. Spot-check in the running app

Open Craftplan, navigate to Manage → Orders, filter to the imported date range, and confirm:
- A handful of order references exist with the expected `BOTTLE-<id>` invoice numbers.
- Customer detail pages show the imported shipping addresses.
- Product list shows the new SKUs with `BOTTLE-PID-` prefix.

### 6. Audit log

Each run appends a line to `priv/imports/bottle/bottle_import_log.jsonl`. Check the latest entry:

```bash
tail -1 priv/imports/bottle/bottle_import_log.jsonl | jq
```

Confirm `inserted_orders + skipped_orders == total orders in window`, `failed_orders == 0`.

## Bootstrap (one-time, first import only)

Before the very first run, populate `priv/imports/bottle/price_map.yml` with retail prices for every PID that appears in the Bottle file but does not yet exist in Craftplan. Format:

```yaml
prices:
  "PID-47420": "10.00"
  "PID-47421": "8.50"
  # ...
```

After the bootstrap, the file should mostly empty out — new SKUs should be created in Craftplan first.

## Out of scope

- **Kit explosion.** `Combo Box (2 of each)` and Galentine's variants import as opaque products with `selling_availability: :off`. Modeling kit decomposition is a separate change.
- **Gift cards.** Dropped at extract time.
- **Resale-supplier POs.** Coffees and honeys here are sales records; their wholesale POs are a separate import.
- **Multi-year backfill.** Supported by this skill's idempotency, but the operational playbook (year-by-year, with checkpoints) is documented separately.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `unknown_pids` is non-empty | Bottle has a SKU not in Craftplan and not in `price_map.yml` | Create in Craftplan or add to yaml; re-run |
| Test failure: `Customer.first_name min_length` | A mononym row reached the DB with empty first_name | Verify `NameParser` returned `"-"`; bug in upsert |
| `tz_world` errors on SlotTimeParser | `Tzdata` data not loaded | Run `mix deps.compile tz --force` |
