---
layout: ../../layouts/DocsLayout.astro
title: Production Batching
description: Batch workflow from creation through completion with auto-FIFO consumption and cost snapshots
---

Production batching groups order items into efficient production runs with full material tracking and cost accounting.

## Batch Lifecycle

A production batch progresses through four statuses:

1. **Open** — Batch created with order-item allocations and a frozen BOM snapshot.
2. **In Progress** — Production has started (`started_at` recorded).
3. **Completed** — Production finished, materials auto-consumed via FIFO, cost snapshot captured.
4. **Canceled** — Batch abandoned (no consumption occurs).

Transitions are enforced: a batch must be started before it can be completed, and completed batches cannot move backward.

## Creating Batches

Batches are created from the planner's day-view kanban board. When you click an unbatched product card and press **Batch All**, the system:

1. Collects all order items for that product on the selected day.
2. Calculates remaining unplanned quantity per item (items already fully allocated to other batches are skipped).
3. Creates the batch via the `open_with_allocations` action, which in a single step:
   - Auto-generates a unique batch code from the product SKU.
   - Snapshots the active BOM version and its `components_map`.
   - Creates `OrderItemBatchAllocation` records linking each order item with its planned quantity.

You can also create a batch without allocations via the `open` action from the batch list page.

## Progressing Batches

From the kanban board or the batch detail modal:

- **Start** — Sets status to `in_progress` and records `started_at`. Can be triggered by clicking the Start button or dragging the card from Open to In Progress.
- **Mark Done** — Opens an inline form to enter the produced quantity and optional duration in minutes. Submitting triggers the `complete` action.

Drag-and-drop on the kanban enforces valid transitions and opens the completion form automatically when dragging from In Progress to Done.

## Material Consumption

When a batch is completed, the `complete` action automatically handles material consumption:

- The `components_map` frozen at batch creation determines required quantities, scaled by produced quantity.
- Lots are selected using auto-FIFO ordering (earliest expiry date first) via `Batching.auto_select_lots/2`.
- Stock is deducted from selected lots via inventory movements (`Batching.consume_batch/3`).
- If stock is insufficient, the action returns an error with the material ID, required amount, and shortage.

### Manual Lot Selection

For cases where auto-FIFO is not appropriate (e.g., specific lot requirements, partial stock), the `complete` action accepts an optional `lot_plan` argument. When provided, the system uses this explicit plan instead of auto-selecting lots.

## Cost Snapshots

On batch completion, the system captures a cost snapshot for each allocated order item via `Batching.complete_batch/2`:

- **Batch code** — Auto-generated identifier for the production run
- **Material cost** — Sum of consumed materials at their buy prices
- **Labor cost** — Calculated from BOM labor steps, hourly rates, and units per run
- **Overhead cost** — Percentage applied from settings configuration
- **Unit cost** — Total cost divided by produced quantity

These snapshots are persisted on the order items for invoicing and COGS reporting.

## BOM Snapshots

The batch locks in the BOM version and components map at creation time. This means:

- Historical batches always reflect the costs that were current when production ran
- Updating a BOM does not retroactively change completed batch costs
- You can compare costs across batches to track efficiency changes over time

## Batch List & Detail Pages

All batches are browsable at **Manage → Production → Batches** (`/manage/production/batches`). The list supports filtering by status and product name with pagination. Each batch detail page (`/manage/production/batches/:batch_code`) shows the product, BOM, allocated order items, and consumed lots.
