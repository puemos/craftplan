# Upstream PR draft — material cost over time

Target repo: [puemos/craftplan](https://github.com/puemos/craftplan)
Reviving: [Issue #4 — "Material cost doesn't get updated when Material cost changed"](https://github.com/puemos/craftplan/issues/4)

> **Note for the fork maintainer:** This draft describes the upstream-suitable subset of the changes. The IGF invoice import skill, the `priv/imports/` directory, and the `external_sku` field's IGF-specific motivation stay in the fork. Only the generic cost-history primitives go upstream.

---

## Title

`feat(inventory): persist per-lot unit cost so material cost over time is queryable`

## Summary

Issue #4 noted that BOM material cost is computed live from `Material.price`, so editing the price retroactively reprices every past order. That bug was fixed at the BOM-rollup level in v0.3.4, but the reporter also asked the broader question:

> "how could you keep track of the materials price changing over time?"

This PR answers that question by giving `Lot` a `unit_cost` attribute and threading it through the `PurchaseOrder.receive` flow, so every received lot freezes the price paid at receipt time.

**What this PR does not do** — change how BOM cost is calculated. The existing `Material.price`-based rollup still drives forward-looking pricing. The new `Lot.unit_cost` is a parallel record of what was actually paid, ready to be consumed by future cost-of-goods-sold reporting (a separate change once consumption movements get linked back to specific lots).

## Changes

### `inventory_lots` table
- New nullable `unit_cost :decimal` column.
- Added to `Lot.create`/`update` accept lists.
- Resource snapshot + migration.

### `PurchaseOrder.receive` action
- `lot_receipts` argument now accepts an optional `unit_cost` per receipt.
- When omitted, falls back to the matching `PurchaseOrderItem.unit_price` for the same `material_id`. Existing callers that don't pass `unit_cost` get the right answer automatically.

### Tests
- `test/craftplan/inventory/lot_unit_cost_test.exs` — creates/reads `Lot.unit_cost` directly, plus two tests for the receive flow (explicit unit_cost; fallback from PO item).

## Backwards compatibility

- `unit_cost` is nullable. Pre-existing lots get `NULL` and continue to work.
- Existing `PurchaseOrder.receive` calls that don't pass `unit_cost` keep working — they now write the PO item's `unit_price` to each lot, which is the right answer 99% of the time. If a caller does *not* want this, they can pass `unit_cost: nil` explicitly per receipt.
- No changes to BOM rollup or recipe cost calculation. `Material.price` remains authoritative for forward-looking cost. This PR is additive.

## Out of scope (for follow-ups)

- **Weighted-average rollback into `Material.price`** on receive (what the reporter literally asked for — "if we have 100 lbs left at $0.55 and add 1000 at $0.60, does it mix?"). Doable as a follow-up that reads `Lot.current_stock` + `Lot.unit_cost`, but it changes BOM costing behavior, which is a bigger conversation worth having separately.
- **Consumption-side lot linkage for COGS** — when a production batch consumes from a lot, capture which lot it came from so retrospective margin analysis can value the consumption at that lot's `unit_cost` instead of the current `Material.price`. Requires changes in `ProductionBatch` / consumption flow.
- **Supplier-side cost report UI** — display `Lot.unit_cost` over time per material somewhere in `/manage/inventory/`. Schema-only PR for now; UI is a downstream change.

## Test plan
- [ ] `mix test test/craftplan/inventory/lot_unit_cost_test.exs`
- [ ] `mix ash.codegen --check` — should report no drift after the resource snapshot is included
- [ ] Existing `test/craftplan/inventory/receiving_test.exs` continues to pass (it doesn't pass `unit_cost`, so it exercises the fallback path)
- [ ] Smoke-test on a fresh database: create supplier → material → PO → PO item with `unit_price` → receive without explicit `unit_cost` → verify lot has the PO item's unit_price as `unit_cost`

## Files

```
priv/repo/migrations/20260622120100_add_unit_cost_to_lots.exs   (new)
priv/resource_snapshots/repo/inventory_lots/20260622120100.json (new)
lib/craftplan/inventory/lot.ex                                  (modified)
lib/craftplan/inventory/purchase_order.ex                       (modified)
test/craftplan/inventory/lot_unit_cost_test.exs                 (new)
```

## Open questions for the maintainer

1. **Should `unit_cost` be exposed via JSON:API / GraphQL?** Current PR leaves it as a regular attribute, which means it shows up on `get_lot` / `list_lots` GraphQL queries automatically (since `Lot` already has those queries defined). No write mutation is added because lots aren't writable via the API anyway. Comfortable with that — flag if you'd prefer something else.
2. **Naming.** `unit_cost` (matches the term used in `BomRollup.unit_cost`) vs `cost_per_unit` vs `acquisition_cost`. Happy to rename.
