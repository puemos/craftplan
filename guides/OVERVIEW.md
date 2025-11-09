# Manage Overview & Planner

The planner now lives under **Manage → Overview** (`/manage/overview`). It is the first stop after logging in and keeps the Operate → Make → Stock loop in one place. The left navigation highlights **Overview** whenever you are on the new landing page or any of its production tabs.

![Planner schedule showing overview, schedule, make sheet, and cost snapshot](../screenshots/plan.png)

## Layout & Tabs

- **Overview (default)** – summarizes today’s commitments, late items, and quick links into orders and purchasing.
- **Schedule** – the familiar calendar grid. Use `week` / `day` toggles and the `stream`-driven cards to drill into a specific product/date combination without leaving the page.
- **Make Sheet** – printable run sheet that hides navigation, injects printer-friendly borders, and can be printed directly via the “Print” button (the browser shortcut `⌘P`/`Ctrl+P` also works).
- **Materials** – rolls up per-material demand, current stock, and shortage warnings for the selected horizon.

The entire surface is LiveView driven, so switching tabs or scrolling dates keeps state without extra navigation.

## Marking Work Done & Cost Snapshots

1. Open the **Schedule** tab and select a cell to open the product modal for that date.
2. Update order item statuses with the badge-select – moving an item to **Completed** runs the BOM consumption flow.
3. When an item is marked done, the modal displays a **Completion Snapshot** card that summarizes:
   - Auto-generated `batch_code`
   - Material, labor, and overhead costs pulled from the active BOM rollup
   - Calculated unit cost for the run
4. Below the snapshot you will see the **consumption recap** table plus a pill-based “Total required” footer grouped by unit. This mirrors the enforcement in `Consumption.consume_item/2` so the numbers match the eventual inventory movement.
5. Use **Consume Now** when you are ready to deduct stock; otherwise pick **Not Now** to leave the recap available while you continue planning.

This snapshot is the “planner cost snapshot” called out in the roadmap and feeds invoices and future insights work.

## Printing & Quick Actions

- The **Make Sheet** dialog exposes the entire day’s run in a printable table. Capacity-limited products respect their `max_daily_quantity` and the sheet mirrors whatever filters you have applied.
- The **Materials** tab mirrors the same “Total required” footer so bakers can confirm if there is enough stock before starting a run.
- `Consume All Completed` on the make sheet consumes every completed item that still has pending stock deductions—handy at the end of the day.

## Tips

- The **Return to Overview** button (or hitting the Overview nav item) always routes to `/manage/overview`, so you can bookmark it for one-click access.
- Planner cards link back to the order detail via the reference badge so customer follow-ups stay close to production.
- If you need to adjust BOMs after seeing the snapshot, use the product link inside the modal; it opens a new tab on `Catalog → Products → Recipe`.

