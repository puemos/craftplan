---
name: igf-import
description: Import a paper-style PDF invoice from International Gourmet Foods (IGF) into Craftplan as a PurchaseOrder + items, then receive it as Lots with unit_cost populated. Triggers on phrases like "import this IGF invoice", "import IGF", "load this IGF receipt", "ingest IGF invoice", or when the user @-references a PDF under a Receipts/ folder named with IGF or an IGF invoice number. Captures per-line unit prices to a price-history log so material-cost-over-time can be reconstructed even before BOM costing reads from lots.
---

# IGF invoice → Craftplan importer

This skill takes an IGF PDF, turns it into a `PurchaseOrder` + items in Craftplan, and receives it as `Lot`s with `unit_cost` populated.

IGF (International Gourmet Foods, Woodbridge VA) is Bread Par Avion's main ingredients supplier. Invoices arrive on paper and get scanned to PDF. Cadence is roughly weekly to bi-weekly.

## Inputs

- `pdf_path` — absolute path to the IGF invoice PDF
- Implicit: a working Craftplan deployment at the URL named in `CRAFTPLAN_API_URL` env (default `https://plan.breadparavion.com`), reachable with `CRAFTPLAN_API_KEY` env (a `cpk_…` bearer token)

## What gets created

For each invoice:
1. One `PurchaseOrder` (supplier = IGF, `ordered_at` = invoice date)
2. One `PurchaseOrderItem` per invoice line (with `material_id`, `quantity` in Craftplan units, `unit_price` in Craftplan units)
3. After confirmation, the PO is **received** — which materializes one `Lot` per line (with `unit_cost`) plus a positive `Movement` for stock

The lot code convention is `IGF-<invoice_no>-L<line_no>` (e.g. `IGF-7367700-L01`).

## Procedure

Follow these steps **in order**. Do not skip the verification gates.

### 1. Extract the line table

Read the PDF with the Read tool. IGF invoices have an embedded text layer — this is OCR-free extraction in normal cases.

Capture per line: `qty_shipped`, `qty_ordered`, `igf_code`, `unit_of_measure` (CASE/JAR/BAG/EACH/BOX), `description`, `unit_price`, `extended_price`.

Capture per invoice: `invoice_no`, `invoice_date`, `customer_no`, `frozen_subtotal`, `refrigerated_subtotal`, `dry_subtotal`, `grand_total`.

### 2. Math gate — verify the extraction

This is non-negotiable. Refuse to proceed if any check fails:

- For every line: `qty_shipped × unit_price ≈ extended_price` (penny tolerance for decimal weirdness)
- Sum of extended prices grouped by section header (`**** Frozen ****`, `**** Refrigerated ****`, `**** Dry ****`) must equal the printed `FROZEN`, `REFRIGERATED`, `DRY` subtotals
- `frozen_subtotal + refrigerated_subtotal + dry_subtotal == grand_total` (no tax, no discount on IGF invoices)

If any check fails, show the user the diff and stop. Do not write anything.

### 3. Map invoice lines to Craftplan materials

For each line, query Craftplan via GraphQL:

```graphql
query($code: String!) {
  listMaterials(filter: { externalSku: { eq: $code } }) {
    results { id sku name unit price }
  }
}
```

Three outcomes per line:

- **Match** — proceed.
- **No match (new SKU)** — surface the line to the user. Ask: create a new Material (need a unit conversion — IGF sells in CASE/BAG/LB; Craftplan stores in gram/milliliter/piece) or alias to an existing Craftplan SKU.
- **Multiple matches** — shouldn't happen because `external_sku` is unique. If it does, halt and ask the user to deduplicate manually before re-running.

For new-material creation, the conversion math:
- "BAG 50-LB" → `unit: :gram`, multiplier `22679.62` g/bag
- "BAG 11-LB" → multiplier `4989.52` g/bag
- "JAR 5-LB" → multiplier `2267.96` g/jar
- "CASE 15 DZ" (eggs) → `unit: :piece`, multiplier `180` pcs/case
- "EACH" → `unit: :piece`, multiplier `1`
- "BOX 3-LB" / "BOX 5-LB" → `unit: :gram`, calc from label
- "CASE 16/800-GR" (Sel Gris) → `unit: :gram`, multiplier `12800` g/case
- "CASE" of fluid (e.g. spray) → `unit: :piece`, multiplier = cans/case (12 typical)

Ask the user when the conversion isn't unambiguous from the description.

After conversion: store the **per-Craftplan-unit** price on the PurchaseOrderItem (`unit_price_per_gram = invoice_unit_price / grams_per_case`), and the **total Craftplan-unit quantity** as `quantity` (`grams = invoice_qty × grams_per_case`).

### 4. Preview gate — show the user

Before writing anything, print a table:

| Line | IGF code | Description | Material (Craftplan SKU) | Invoice qty × unit$ | Craftplan qty × unit$ |

Plus: supplier IGF UUID, invoice number, invoice date, grand total.

Wait for explicit user confirmation. "Yes" / "looks right" / "go" all count. Anything else means stop.

### 5. Write — GraphQL mutations

In order:

1. `createPurchaseOrder` — `supplier_id` = IGF UUID, `ordered_at` = invoice date (UTC), `status: "ordered"`.
2. `createPurchaseOrderItem` × N — one per line, with `material_id`, Craftplan `quantity`, Craftplan `unit_price`.
3. Update the PO via the `receive` action with a `lot_receipts` array — one entry per item: `{material_id, lot_code: "IGF-<invoice_no>-L<NN>", quantity, expiry_date?, unit_cost}`. The receive action will create Lots + Movements and the `unit_cost` falls back to `unit_price` on the line if not explicitly set (so explicit is optional but recommended for clarity).

If any mutation fails, show the user the error and stop. Do not retry automatically — the user should decide whether to fix-and-retry or abandon the PO.

### 6. Append to the price history log

Even though `Lot.unit_cost` now captures cost over time at the schema level, also write each line to `priv/imports/igf_price_history.jsonl` (append-only). Format:

```json
{"invoice_no":"7367700","invoice_date":"2026-06-16","igf_code":"34998","craftplan_sku":"flour-kasp","description":"Flour, King Arthur Special 50-LB","invoice_qty":8,"invoice_unit":"BAG","invoice_unit_price":"25.79","craftplan_qty":"181436.96","craftplan_unit":"gram","craftplan_unit_price":"0.001137","lot_code":"IGF-7367700-L08","extended":"206.32"}
```

This is the disaster-recovery / cross-check / re-import-friendly archive. If a Craftplan write fails halfway through, the log tells us exactly what was meant to happen.

### 7. Report back to the user

One sentence summarizing what was created, with the PO reference and the URL of the PO in the deployed UI (`<base>/manage/inventory/purchase-orders/<reference>`).

## Mapping table

A persistent mapping file lives at `priv/imports/igf_material_map.yml`. Format:

```yaml
# IGF product code → Craftplan material SKU
"34998": flour-kasp
"NSFL500": flour-galahad
"35019": flour-ww-fsg
"NSSA357": salt-sel-gris
"40167": butter-unsalted-aa
```

This file is the source of truth for the `external_sku` field on Materials. After step 3 creates or aliases a Material, append to this file so future invoices auto-resolve without prompting.

## Out of scope

- Multi-supplier invoices (this skill is IGF-specific; other vendors get their own skills or a generic version once we have ≥2 paper-invoice suppliers)
- Returns / credit memos (treat as a separate workflow when we see one)
- Currency conversion (IGF is USD; if Craftplan adds multi-currency we'll revisit)
- OCR-only invoices (this skill assumes the PDF has an embedded text layer; if a scan-only invoice arrives, escalate to the user — don't guess)
