# Bottle order-report importer — Design

**Status:** Draft for review
**Date:** 2026-06-22
**Author/Driver:** Tim Chambers (with Claude)
**Scope:** First production import of the 2026-01-01 → 2026-06-20 Bottle export, plus a reusable mechanism for monthly recurring imports and an eventual multi-year backfill.

## 1. Problem

Bread Par Avion's e-commerce platform (Bottle) emits an XLSX order report. Craftplan needs to ingest this data so that historical revenue, customer history, and product demand all live in one place. The current report covers ~4,300 orders, 600+ customers, and 65 distinct SKUs. Future monthly drops and historical years (multiple of them) need to use the same path.

The Bottle XLSX is wide, idiosyncratic, and shares no schema with Craftplan. Several Craftplan fields the importer must populate are not present in the export — most importantly per-line product prices and a per-Order external identifier — so the design must explicitly cover those gaps.

## 2. Goals

1. Import the 2026-01-01 → 2026-06-20 Bottle report end-to-end: products, customers, orders, order items.
2. Make every import re-runnable. Re-running a previously-imported file must be a no-op.
3. Make the workflow reusable: monthly imports and a multi-year backfill share the same mechanism.
4. Surface a preview before any database write so the operator can inspect counts and missing data.
5. Treat Craftplan as the source of truth for `Product` data after the first run — never silently overwrite product fields on re-import.

## 3. Non-goals

- **Kit/combo-box explosion.** Five SKUs (`Combo Box (2 of each)` + 4 Galentine's variants) are imported as opaque products with `selling_availability = :off`. Modeling them as kits is deferred to a separate change.
- **Gift cards.** The four `$10/$40/$50/$100 Gift Card` SKUs are dropped at extract time.
- **BOM/material wiring.** Manufactured products land without a BOM. Adding BOMs is out of scope.
- **Resale-supplier POs.** The user mentioned wanting to import wholesale POs for coffee and honey eventually; that is a separate skill.
- **Per-order address history.** Only the most-recent shipping address per customer is preserved.
- **Per-order store distinction.** Bottle reports two stores ("Bread Par Avion" and "Father's Day Specials!"); store membership is not persisted.

## 4. Architecture

A two-stage importer composed via a Claude Code skill:

```
bottle XLSX
   │
   ▼
priv/imports/bottle/extract.py            ← stage 1: parse + clean (Python, pandas)
   │  writes a fresh run dir
   ▼
priv/imports/bottle/runs/<ts>/
   ├── products.csv      (with category column)
   ├── customers.csv     (phone-deduped, mononyms flagged)
   ├── orders.csv        (one row per Bottle ID; gift-card-only orders dropped)
   └── order_items.csv   (one row per non-zero (Bottle ID, PID) cell)
   │
   ▼
mix bottle.import <run_dir>               ← stage 2: ingest (Elixir, direct Ash)
   │
   ▼
Craftplan DB (Customer / Product / Order / OrderItem)
```

A persistent **price map** at `priv/imports/bottle/price_map.yml` (PID → retail price decimal USD) is consulted **only as a bootstrap fallback** when the importer encounters a Bottle PID that does not yet correspond to a Craftplan `Product`. After the initial bootstrap, the map is mostly empty / inert; Craftplan owns product pricing.

The skill at `.claude/skills/bottle-import/SKILL.md` orchestrates: extract → preview → confirm → ingest → verify, with idempotency gates so partial / re-runs are safe.

## 5. Components

| Component | Purpose | Path |
|---|---|---|
| `extract.py` | Bottle XLSX → 4 CSVs in a timestamped run dir. Filters to fulfillment window (CLI args `--from` / `--to`), drops gift cards, classifies products (`manufactured` / `resale_coffee` / `resale_honey` / `kit`), dedupes customers by phone, flags mononyms. | `priv/imports/bottle/extract.py` |
| `price_map.yml` | PID → retail price (decimal USD). Manually maintained bootstrap fallback. Consulted only when a `BOTTLE-<PID>` SKU isn't found in Craftplan. | `priv/imports/bottle/price_map.yml` |
| `Mix.Tasks.Bottle.Import` | Reads CSVs + price map; resolves/upserts Customers → Products → Orders/Items via direct Ash. Skips orders whose `invoice_number = "BOTTLE-<bottle_id>"` already exists. | `lib/mix/tasks/bottle/import.ex` |
| `Craftplan.BottleImport.Upserts` | Pure functions for the three resolve/upsert flows. Testable in isolation. | `lib/craftplan/bottle_import/upserts.ex` |
| `Craftplan.BottleImport.NameParser` / `.PhoneNormalizer` / `.SlotTimeParser` | Small focused modules for the deterministic transformations (mononym handling, phone scrubbing, US/Eastern fulfillment slot → UTC). Each unit-tested in isolation. | `lib/craftplan/bottle_import/` |
| `SKILL.md` | Agent-facing instructions: triggers, procedure, gates, verification. | `.claude/skills/bottle-import/SKILL.md` |
| `bottle_import_log.jsonl` | Append-only audit log of every import run (file path, counts, timing, errors). Recovery aid. | `priv/imports/bottle/bottle_import_log.jsonl` |

### Why two stages

Splitting extract from ingest:
- Makes the intermediate state a set of plain CSVs that operators can inspect, edit, and re-ingest.
- Lets the preview gate run against deterministic on-disk artifacts, not in-memory state.
- Lets us reuse the already-working Python extractor instead of reimplementing XLSX parsing in Elixir.
- Decouples the two languages so the ingest layer (the part that touches the DB) is pure Elixir + Ash.

## 6. Data flow & mapping

### Customer

| Bottle source | Craftplan target | Note |
|---|---|---|
| `Customer Name` (single token) | `Customer.first_name = "-"`, `Customer.last_name = <name>` | Mononym handling. `is_mononym=true` flag in customers.csv. |
| `Customer Name` (≥2 tokens) | `Customer.first_name = <token[0]>`, `Customer.last_name = join(tokens[1..])` | |
| `Phone` (digits-only, ≥10) | `Customer.phone` — **identity key for upsert** | All rows have a valid phone in this dataset. |
| `Email` | `Customer.email` | Optional. |
| `Address1/2`, `City`, `State`, `Zip` | `Customer.shipping_address` (embedded `Address`) | Last-write-wins, where "last" = highest `Transaction Date` across all Bottle rows for this phone within the current run. The Mix task sorts rows by `Transaction Date` ascending before processing customers so the final write is the most recent. |
| (constant) | `Customer.type = :individual` | |

### Product

| Bottle source | Craftplan target | Note |
|---|---|---|
| `(name)` parsed from product column header | `Product.name` | |
| `(PID-…)` parsed from product column header | `Product.sku = "BOTTLE-<PID>"` — **identity key for upsert** | |
| `price_map.yml[PID]` *(creation only)* | `Product.price` | Used **only** when creating a new product; existing products are never re-priced. |
| `category == :kit` | `Product.selling_availability = :off`, `Product.status = :active` | Defers kit modeling. |
| `category != :kit` | `Product.selling_availability = :available`, `Product.status = :active` | |

### Order

| Bottle source | Craftplan target | Note |
|---|---|---|
| `Bottle ID` | `Order.invoice_number = "BOTTLE-<id>"` — **idempotency key** | |
| `Phone` → resolved `Customer.id` | `Order.customer_id` | |
| Start of `Fulfillment Slot Time` | `Order.delivery_date` (UTC) | Parsed in US/Eastern → UTC. See §6.1. |
| `Fulfillment Method` | `Order.delivery_method` | `Maketto Pickup` → `:pickup`; all others → `:delivery`. |
| `Payment Status == "Paid"` (universally true) | `Order.payment_status = :paid`, `Order.paid_at = Transaction Date` (UTC) | |
| (constant) | `Order.status = :complete`, `Order.payment_method = :card`, `Order.currency = :USD` | Historical orders; Bottle is card-only. |

### OrderItem

| Bottle source | Craftplan target | Note |
|---|---|---|
| Non-zero, non-NaN cell in product column | One `OrderItem` row | |
| Resolved product's `Product.price` | `OrderItem.unit_price` | Always read from DB at import time — never from yaml directly. |
| Cell integer value | `OrderItem.quantity` | |
| (constant) | `OrderItem.status = :todo` | Default. |

### 6.1 Slot-time parsing

The `Fulfillment Slot Time` column is a string like `"1/13 05:00AM - 1/13 12:00PM"`. We parse the leading date/time as a naive value in US/Eastern (handling DST via Elixir's standard timezone database), combine it with the `Fulfillment Slot Day` year (Bottle's date-only year is reliable), and convert to UTC. Implementation lives in `Craftplan.BottleImport.SlotTimeParser` with a focused test table.

## 7. Pricing resolution

For each Bottle PID encountered:

1. Look up `Product` by `sku = "BOTTLE-<PID>"`.
2. **Found** → use as-is. `OrderItem.unit_price = Product.price`. Do not modify any `Product` field.
3. **Not found** → check `price_map.yml`. If present, create a new `Product` with `name`, `sku`, `price` from the map. Then `OrderItem.unit_price = Product.price`.
4. **Not found anywhere** → abort with a clear, actionable error:
   > `Unknown PID PID-110803 (Sourdough Biscuits (4)). Create it via Manage → Products with the correct retail price, then re-run. Or add the PID to priv/imports/bottle/price_map.yml.`

This ensures Craftplan owns product data after the bootstrap; monthly imports become read-only on the product side. Note the asymmetry with customers: `Customer.shipping_address` *is* updated on re-import (sales data is the freshest source of where to ship). `Product` fields are *not* — staff edits in Craftplan must persist across imports.

## 8. Idempotency

| Entity | Identity → upsert key |
|---|---|
| Customer | `phone` (unique identity already defined on resource) |
| Product | `sku` (unique identity already defined on resource) |
| Order | `invoice_number = "BOTTLE-<bottle_id>"` — must be unique. Importer checks existence before insert. |

Re-running the importer against the same Bottle file produces zero net DB changes. Partial / failed runs are safe to retry — already-written orders are skipped.

> **Schema note:** `Order.invoice_number` is currently a nullable string with no unique constraint. We rely on the importer's pre-write existence check for idempotency. Adding a unique index is out of scope but recommended in a follow-up — see §11.

## 9. Error handling & gates

1. **Preview gate** — before any DB write, the Mix task prints:
   - New customers (N), updated customers (M).
   - Products: existing (X), to be created from price_map (Y), unknown PIDs (Z + list).
   - Orders: to insert (R), to skip (S already imported).
   - Requires explicit `y` confirmation. `--yes` flag for non-interactive runs.
2. **Unknown PIDs block.** If Z > 0 the gate refuses to proceed and prints the actionable error message above for every unknown PID.
3. **Per-order isolation.** Each `Order` (with all its `OrderItem`s) is written inside its own Repo transaction. If any single item write fails the whole order rolls back and the order is recorded as failed in the audit log; the run continues with the next order. The final run summary lists all failures with their Bottle IDs.
4. **Audit log.** Every run appends one JSON line to `bottle_import_log.jsonl` with: timestamp, run dir path, file path, counts (parsed/created/updated/skipped/failed), elapsed seconds, error count.

## 10. Testing

### Unit tests (async)
- `NameParser` — mononym, two-token, ≥3-token, empty, whitespace cases.
- `PhoneNormalizer` — `(202) 590-8525` → `2025908525`; rejects <10-digit inputs.
- `SlotTimeParser` — `"1/13 05:00AM - 1/13 12:00PM"` with `slot_day=2026-01-13` → `~U[2026-01-13 10:00:00Z]` (EST); same logic across DST boundary (`"3/15 05:00AM - 3/15 12:00PM"`, `slot_day=2026-03-15` → `~U[2026-03-15 09:00:00Z]` EDT).
- `Upserts.resolve_product/2` — existing-by-sku, create-from-price-map, unknown-PID error.

### Integration tests (`DataCase`, async)

Fixture: tiny synthetic CSV set (≈10 customers, 5 products, 20 orders, 40 items, includes one mononym customer, one `Maketto Pickup`, one product missing from price_map for the negative-path test).

- First run inserts the expected counts.
- Second run against the same CSVs is a no-op (idempotency).
- Order with mononym customer creates `Customer` with `first_name == "-"`.
- Order with `Maketto Pickup` lands as `delivery_method: :pickup`.
- Order with `Delivery` lands as `delivery_method: :delivery`.
- Unknown-PID gate aborts with no partial writes (verified by row counts).
- Customer phone identity dedup — two Bottle rows for the same phone produce one `Customer`, last-shipping-address wins.

### E2E (the actual file)

Targets for this Bottle file (2026-01-01 → 2026-06-20):
- Customers: **609**
- Products: **65** (44 manufactured + 12 resale_coffee + 4 resale_honey + 5 kit; gift cards excluded)
- Orders: **4,305**, no duplicates after a second run
- OrderItems: **7,505**
- Total units: **8,168**

E2E run procedure:
1. Run `extract.py` against the file → confirm row counts match expected.
2. Populate `price_map.yml` for all 65 PIDs (interactive prompt or pasted list).
3. Run `mix bottle.import <run_dir>` → preview gate confirms counts → confirm → ingest.
4. Verify counts via `mix bottle.import.verify <run_dir>` (or equivalent `iex` queries documented in the skill).
5. Re-run the import → preview gate reports 0 inserts / 4,305 skips → confirm idempotency.

## 11. Out of scope but worth follow-ups

> **Notes (added during E2E):**
>
> 1. `Product.name` regex was relaxed to also allow ASCII `(`, `)`, `'`, `'` (U+2019 curly apostrophe), `–` (U+2013 en-dash), `&` (ampersand), and `…` (U+2026 ellipsis) to accommodate real Bottle product names such as `"Combo Box (2 of each)"`, `"Galentine's Day Cookie Box (BFF)"`, `"Cinnamon Raisin Swirl Bread – Tuesdays"`, `"Fresh Currant & Chocolate Scones (4)"`, and `"Galentine's Day Cookie Box (I love you more than…)"`.
> 2. `Customer.first_name` / `Customer.last_name` regex was relaxed to allow `'`, `,`, and `'` (U+2019) — real customer names include suffixes like `"Michael Letschin, MBA"` and apostrophes like `"O'Brien"` / `"O'Brien"`.
> 3. `Upserts.parse_utc_datetime/1` was made tolerant of `nil` and empty strings — 5 Bottle rows had a missing `Transaction Date`, and `Order.paid_at` is nullable.
> 4. `Upserts.upsert_customer/2` clears `email` for the second-and-later customer that would collide with `Customer`'s email-unique identity. Households commonly share an email under distinct phones (e.g., Page Buchanan and Dianne Schindler both used `Pagepsb@gmail.com`); the importer keeps the email on the first phone seen and blanks it on the rest. Phone remains the identity key for upsert.

- **Add a unique index on `Order.invoice_number`** — currently nullable+un-indexed; the importer's pre-write check is a soft guard. A migration adding a partial unique index (`WHERE invoice_number IS NOT NULL`) would harden idempotency.
- **Kit modeling** — five SKUs are opaque today. Future change: `Product.kit_items` relationship that decomposes at fulfillment / inventory time.
- **Resale supplier POs** — coffees (Annuals + Single Origins + Destroyer + Climate Project) and honeys come from wholesale suppliers. POs are a separate import.
- **Per-order delivery address** — currently only the most-recent address survives. Adding an embedded `Address` to `Order` would preserve history.
- **Store retention** — adding a nullable `Order.source_channel` or similar would let us slice by Bottle store.
- **Multi-year backfill** — the design supports it (idempotency + per-order isolation + audit log), but the actual yearly runs are a separate, later workflow.

## 12. Verification of the design itself

Before writing the plan:
- [x] Every required Craftplan attribute on `Customer`, `Product`, `Order`, `OrderItem` is sourced from a Bottle field or a documented constant.
- [x] Every Bottle field used for upsert keys (`Phone`, `PID`, `Bottle ID`) has a corresponding unique identity in Craftplan or a guarded fallback.
- [x] The two timezone-sensitive fields (`delivery_date`, `paid_at`) have explicit conversion rules.
- [x] Every dropped/deferred SKU class (gift cards, kits) has a documented handling.
- [x] The price-resolution flow has a terminating "abort with actionable error" branch — no silent zero-prices.
- [x] Idempotency is keyed off a field that exists today (`invoice_number`), with a follow-up to harden it.
