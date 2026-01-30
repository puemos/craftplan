---
layout: ../../layouts/DocsLayout.astro
title: Overview & Planner
description: The Manage Overview landing page with schedule, make sheet, and materials tabs
---

The planner lives at **Manage → Overview** (`/manage/overview`). It is the first page you see after signing in and keeps the plan-make-stock loop in one place.

![Craftplan Planner](/craftplan/screenshots/plan.webp)

## Layout & Tabs

The planner is organized into four tabs:

- **Overview** (default) — Summarizes today's commitments, late items, and quick links to orders and purchasing.
- **Schedule** — Calendar grid with week/day toggles and stream-driven cards. Drill into a specific product/date combination without leaving the page.
- **Make Sheet** — Printable run sheet that hides navigation and injects printer-friendly borders. Print via the "Print" button or `Cmd+P` / `Ctrl+P`.
- **Materials** — Rolls up per-material demand, current stock, and shortage warnings for the selected horizon.

The entire surface is LiveView-driven — switching tabs or scrolling dates keeps state without extra navigation.

## Marking Work Done & Cost Snapshots

1. Open the **Schedule** tab and select a cell to open the product modal for that date.
2. Update order item statuses with the badge-select. Moving an item to **Completed** runs the BOM consumption flow.
3. When an item is marked done, the modal displays a **Completion Snapshot** card:
   - Auto-generated batch code
   - Material, labor, and overhead costs from the active BOM rollup
   - Calculated unit cost for the run
4. Below the snapshot you'll see the **consumption recap** table plus a pill-based "Total required" footer grouped by unit.
5. Use **Consume Now** to deduct stock, or **Not Now** to leave the recap available while you continue planning.

The snapshot feeds invoices and future insights features.

## Printing & Quick Actions

- The **Make Sheet** dialog shows the entire day's run in a printable table. Capacity-limited products respect their `max_daily_quantity`.
- The **Materials** tab mirrors the "Total required" footer so you can confirm stock before starting a run.
- **Consume All Completed** on the make sheet consumes every completed item with pending stock deductions — useful at the end of the day.

## Tips

- The **Return to Overview** button (or the Overview nav item) always routes to `/manage/overview`. Bookmark it for one-click access.
- Planner cards link back to the order detail via the reference badge for quick customer follow-ups.
- To adjust BOMs after seeing the snapshot, use the product link inside the modal — it opens a new tab on Catalog → Products → Recipe.
