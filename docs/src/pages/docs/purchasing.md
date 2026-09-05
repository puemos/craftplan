---
layout: ../../layouts/DocsLayout.astro
title: Purchasing
description: Suppliers, purchase orders, and receiving into stock
---

The Purchasing module handles supplier relationships and the procurement of raw materials.

## Suppliers

Navigate to **Manage → Purchasing → Suppliers** to manage your supplier directory. Each supplier record includes:

- Company name and contact details
- Associated materials they supply
- Order history

## Purchase Orders

Create purchase orders to replenish inventory:

1. Select a supplier
2. Add line items with materials and quantities
3. Set expected delivery date
4. Submit the order

Purchase orders track their status through the procurement process.

## Receiving into Stock

When a purchase order arrives:

1. Open the purchase order
2. Select **Receive Stock**
3. Choose **Receive all** or **Partial delivery**
4. Enter the supplier lot code, quantity, and optional expiry date for each lot
5. Split a line when the same material arrives under multiple supplier lot codes
6. Confirm the receipt

Each supplier lot creates its own Craftplan lot and **Receive** movement. The receipt freezes the supplier, purchase order, quantity, and expiry provenance. Partially received purchase orders stay open with visible received progress until the remaining quantity arrives.

The supplier lot links on the purchase-order item open its forward trace in the [Trace Center](/craftplan/docs/traceability/).

## Integration with Forecasting

The inventory forecasting system factors in pending purchase orders when calculating material availability. This prevents duplicate ordering when a PO is already in transit for materials showing as low stock.
