# Catalog & BOM Editor

The Catalog area centralizes product setup, cost rollups, and pricing guidance. All of the “Recipe” functionality now rides on Bills of Materials (BOMs) with simple versioning—no additional flags or feature toggles are necessary.

## Navigating to the Editor

1. Go to **Manage → Catalog → Products**.
2. Pick any product and stay on the **Details** tab to review pricing guidance, or switch to the **Recipe** tab to edit the BOM.

## Simple BOM Versioning

- The header shows the current `vN` along with a “Latest” chip. Older versions display a gold banner with a **Go to latest** shortcut and every input switches to read-only.
- **Show version history** opens a modal listing each version, its status, published timestamp, and unit cost pulled from the cached rollup. Selecting **View** patches in-place to that version.
- Saving always creates a brand-new active BOM (`:status = :active`, `published_at` set to now) and archives the previous active one automatically. No promote/duplicate actions are exposed in the simplified UX.
- The editor honors `?v=NUMBER` in the URL, so you can deep link directly to a specific historical version when reviewing changes.

## Materials, Sub-assemblies & Totals

- The materials grid still preserves its DOM IDs for existing LiveView tests. Each row links back to the inventory SKU and shows per-row totals using the material’s buy price.
- Use **Add Material** to pick from stocked materials or **Add Sub-assembly** to pull another product’s BOM into the current one (`component_type: :product`). Selected items disappear from the picker so you cannot duplicate entries accidentally.
- The table header displays running totals (`Total Cost`) so you always see the material spend per product run.

## Labor Steps & Scaling Guidance

- The **Labor steps** card surfaces the configured hourly rate and overhead from **Manage → Settings → General** with a direct “Update in settings” link.
- Each row captures a named step, duration (minutes), `units_per_run`, and an optional rate override.
  - `units_per_run` defaults to `1`. If a mixing step produces four trays at once, set it to `4` so minutes are divided by four when calculating per-unit cost.
  - Rate overrides accept decimals and allow differentiating specialized labor (e.g., decorate vs. prep).
  - Steps cannot be blank and `units_per_run` must be ≥ 1, matching the validations enforced in `Catalog.LaborStep`.
- The right-most column shows the per-unit labor cost per step, and the header displays both the accumulated minutes and the per-unit total. Overhead percentages are applied later via the rollup.

## Notes & Save Behavior

- Rich-text is not required—general process notes live in the “General notes” textarea beneath the labor grid. It persists alongside the BOM version.
- The **Save Recipe** button is only available on the latest version and disables itself unless there are changes and the form is valid.

## Pricing Guidance & Cost Rollups

- On the **Details** tab you will find a `Suggested Prices` card with retail and wholesale recommendations. These values call `apply_markup/3`, using the current BOM unit cost and the markup mode/value pairs configured in settings (`percent` or `fixed`).
- Materials, labor, and overhead costs are persisted in `catalog_bom_rollups`. The planner, invoices, and future insights features read from the rollup first, so keeping BOMs current is critical.
- Batch completions copy the BOM’s `material_cost`, `labor_cost`, `overhead_cost`, and `unit_cost` onto each finished order item. Those numbers power the **Completion Snapshot** inside the planner modal and future COGS reports.

