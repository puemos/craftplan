---
layout: ../../layouts/DocsLayout.astro
title: Production Batching
description: Batch workflow from allocation through consumption to completion with cost snapshots
---

Production batching groups order items into efficient production runs with full material tracking and cost accounting.

## Batch Workflow

A production batch progresses through these stages:

1. **Open** — Batch created, ready for order items to be allocated
2. **Allocate** — Order items assigned to the batch based on product and delivery date
3. **Start** — Production begins, materials are reserved
4. **Consume** — Raw materials deducted from inventory lots based on BOM quantities
5. **Complete** — Production finished, cost snapshot captured

## Allocating Order Items

Order items are allocated to batches based on:

- Product type (items for the same product are grouped)
- Delivery date alignment
- Production capacity

The planner's schedule view makes it easy to see which items are allocated to which batches.

## Material Consumption

When a batch moves to the consume stage:

- The system reads the active BOM for each product in the batch
- Required material quantities are calculated from BOM components
- Stock is deducted from available inventory lots
- Consumption movements are recorded in the inventory audit trail

The consumption recap shows a breakdown of materials used, grouped by unit, matching the enforcement in the consumption logic.

## Cost Snapshots

On batch completion, the system captures a cost snapshot for each order item:

- **Batch code** — Auto-generated identifier for the production run
- **Material cost** — Sum of consumed materials at their buy prices
- **Labor cost** — Calculated from BOM labor steps, hourly rates, and units per run
- **Overhead cost** — Percentage applied from settings configuration
- **Unit cost** — Total cost divided by produced quantity

These snapshots are persisted on the order items and power the **Completion Snapshot** card in the planner modal, as well as future COGS reporting.

## BOM Snapshots

The batch locks in the BOM version that was active at the time of completion. This means:

- Historical batches always reflect the costs that were current when production ran
- Updating a BOM does not retroactively change completed batch costs
- You can compare costs across batches to track efficiency changes over time
