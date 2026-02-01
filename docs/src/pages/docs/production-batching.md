---
layout: ../../layouts/DocsLayout.astro
title: Production Batching
description: Batch workflow from allocation through completion with auto-FIFO consumption and cost snapshots
---

Production batching groups order items into efficient production runs with full material tracking and cost accounting.

## Batch Workflow

A production batch progresses through these stages:

1. **Open** — Batch created, ready for order items to be allocated
2. **Allocate** — Order items assigned to the batch based on product and delivery date
3. **Start** — Production begins, materials are reserved
4. **Complete** — Production finished, materials auto-consumed from lots via FIFO, cost snapshot captured

The complete step automatically consumes raw materials using FIFO (first-expiry, first-out) lot selection and calculates costs in a single action.

## Allocating Order Items

Order items are allocated to batches based on:

- Product type (items for the same product are grouped)
- Delivery date alignment
- Production capacity

The planner's schedule view makes it easy to see which items are allocated to which batches.

## Material Consumption

When a batch is completed, the system automatically handles material consumption:

- The BOM snapshot frozen at batch creation determines required quantities
- Lots are selected using FIFO ordering (earliest expiry date first)
- Stock is deducted from selected lots via inventory movements
- If stock is insufficient, the operator is prompted to use manual lot selection

### Manual Lot Selection

For cases where auto-FIFO is not appropriate (e.g., specific lot requirements, partial stock), operators can toggle **Advanced: Manual Lot Selection** on the completion form to explicitly choose which lots and quantities to consume.

## Cost Snapshots

On batch completion, the system captures a cost snapshot for each order item:

- **Batch code** — Auto-generated identifier for the production run
- **Material cost** — Sum of consumed materials at their buy prices
- **Labor cost** — Calculated from BOM labor steps, hourly rates, and units per run
- **Overhead cost** — Percentage applied from settings configuration
- **Unit cost** — Total cost divided by produced quantity

These snapshots are persisted on the order items and power the **Completion Snapshot** card in the planner modal, as well as future COGS reporting.

## BOM Snapshots

The batch locks in the BOM version that was active at the time of creation. This means:

- Historical batches always reflect the costs that were current when production ran
- Updating a BOM does not retroactively change completed batch costs
- You can compare costs across batches to track efficiency changes over time
