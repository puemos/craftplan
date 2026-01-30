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
2. Confirm received quantities (which may differ from ordered quantities)
3. Receiving creates inventory lots and stock movements automatically

Each received item generates a **Receive** movement in the inventory audit trail, linking the stock back to the supplier and purchase order for full traceability.

## Integration with Forecasting

The inventory forecasting system factors in pending purchase orders when calculating material availability. This prevents duplicate ordering when a PO is already in transit for materials showing as low stock.
