---
layout: ../../layouts/DocsLayout.astro
title: Traceability & Recalls
description: Trace supplier lots forward, finished batches backward, and prepare a recall record
---

Craftplan preserves the links between a supplier receipt, its ingredient lots, completed production batches, and customer orders. Open **Manage → Production → Traceability** to investigate that chain without reconstructing it from separate screens.

<figure class="not-prose my-8">
  <picture>
    <source
      media="(max-width: 639px)"
      srcset="/craftplan/screenshots/traceability-recall-mobile.webp"
      width="390"
      height="780"
    />
    <img
      src="/craftplan/screenshots/traceability-recall.webp"
      alt="Craftplan Trace Center in recall mode showing the source lot, the hold action, and affected-scope totals"
      width="1144"
      height="420"
      loading="eager"
      decoding="async"
      class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm"
    />
  </picture>
  <figcaption class="mt-3 text-center text-sm text-stone-500">
    Recall mode puts the immediate hold action and affected scope in one clear view.
  </figcaption>
</figure>

## Choose a trace direction

The Trace Center supports three focused workflows:

| Direction | Start with | Answers |
| --- | --- | --- |
| **Forward** | A supplier or internal ingredient lot code | Which batches used this lot, how much was consumed, and which customers received the finished product? |
| **Backward** | A finished product batch code | Which ingredient lots, suppliers, and purchase orders contributed to this batch? |
| **Recall** | An ingredient lot or finished batch code | What stock, batches, orders, and customer destinations are affected, and what should happen next? |

Recent traceable records appear when no search is active. You can also scan or enter a complete code in the search field.

## Forward lot trace

A forward trace shows the full genealogy from supplier to destination:

1. Supplier and purchase-order provenance
2. Ingredient lot and material
3. Finished batches that consumed the lot
4. Customer orders and shipping destinations

Consumed quantities come from the frozen production allocation, not a current BOM estimate. This keeps historical results stable when recipes or material details change later.

## Backward batch trace

A backward trace starts with a finished batch and lists every consumed ingredient lot. Each source includes its material, supplier lot code, supplier, purchase order, and used quantity. Supplier lot codes link directly to their forward trace.

The same result lists the customer orders allocated to the finished batch. On smaller screens, these records are shown as labeled cards so identifiers and provenance remain readable.

## Recall workflow

Recall mode adds an operational summary and response checklist to the forward trace.

1. **Stop further use** — Select **Place lot on hold**. Held lots are immediately excluded from automatic FIFO/FEFO selection.
2. **Isolate remaining stock** — Use the stock-on-hand value to locate and isolate the physical inventory.
3. **Contact destinations** — Work through every affected customer and shipping address shown in the frozen trace.
4. **Preserve the record** — Export the result as CSV or print the trace report for the recall file.

Use **Release hold** only after the lot has been cleared for production. Rejected lots remain unavailable.

## Traceable receiving

Traceability begins when a purchase order is received. Record the supplier lot code for every delivery, split a material across multiple lots when needed, and capture each quantity and expiry date separately. Craftplan generates an internal lot code while retaining the supplier code operators see on packaging and paperwork.

Partial deliveries do not close the purchase order. The item shows received progress and remains available for another receipt until its ordered quantity is complete.

## Frozen batch labels

Completed production batches can be printed in A5 or compact formats. Labels use the batch snapshot for ingredients, allergens, nutritional values, durability date, origin, storage instructions, and food business operator details. The printed batch code and barcode provide the starting point for a backward trace.

Review the setup warning before using a label on packaged food; it identifies required product or business information that is still missing.

## Export and audit integrity

CSV export and print output use the same trace result shown on screen. Supplier receipt details and production allocations are frozen at the time of the operation, preserving the historical chain even when current catalog data changes.
