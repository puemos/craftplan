---
layout: ../../layouts/DocsLayout.astro
title: Produced & Stocked Intermediates
description: Choosing between recipe subassemblies and stocked materials, avoiding duplicate consumption, and understanding current traceability limits
---

An intermediate, such as a blend used by both a solid product and a spray, can be either a reusable recipe or a stocked ingredient. Craftplan currently has no automatic workflow that produces a batch into material inventory and links its input lots to its output lot.

## Choose the model by what you need to track

| Model | What it provides | What it does not provide |
| --- | --- | --- |
| **Product used as a subassembly** | Reusable BOM, recipe cost rollup, and underlying material requirements in finished production | A separate stock balance for the intermediate or an intermediate output lot |
| **Inventory material** | Quantity on hand, lots, and consumption of the blend by several finished products | A production recipe that automatically deducts the blend's own ingredients |

A product's production quantities describe completed batches and order allocations. They are not an available inventory balance. Completing a batch does not create an inventory lot for its output.

## Subassemblies: reuse the recipe without a separate stock stage

Use this model when the blend is made as part of the finished-product run and you do not need to hold it in inventory:

1. Create the blend as a product and define its recipe using raw materials.
2. In each finished product's **Recipe** tab, choose **Add Product** and select the blend. Some versions call this **Add Sub-assembly**.
3. Enter how many units of the blend's recipe are needed per finished unit. For example, if one blend recipe describes 100 g, a component quantity of `0.2` means 20 g per finished unit.
4. Plan and complete batches for the finished products.

The subassembly is a recipe expansion, not a withdrawal from a blend stock balance. Finished-batch consumption uses the underlying materials in its frozen recipe snapshot.

**Do not complete a separate blend batch and then expect the finished batch to consume that blend's output.** The finished batch does not draw from intermediate stock. If both batches include the same raw materials, both will deduct those materials. For example, making a separate 100 g blend and subsequently making a product that expands another 20 g of that recipe consumes the raw materials for 120 g, even if you physically used 20 g of the first blend.

Nested material and allergen resolution has a separate correction tracked in [issue #49](https://github.com/puemos/craftplan/issues/49). That correction does not add intermediate inventory.

## Stocked blends: use a material with a manual production record

If the priority is knowing that 250 g of blend remain and consuming it from several products, model the blend as an **Inventory material** in grams. Add that material to each finished recipe with **Add Material**.

Until production into inventory is supported, mixing the blend requires an operator-maintained record:

1. Record the blend run identifier, input material lot codes, actual input quantities, measured yield, and date.
2. Deduct those input quantities once from their actual raw-material lots.
3. Create a material lot for the blend run and add the measured output quantity to that lot.
4. Complete finished-product batches against the blend material. They consume the blend lot, rather than expanding its raw ingredients again.

Set the blend material's price, allergens, and nutritional facts explicitly. Those values are not automatically inherited from a separate product recipe. Account for actual yield and losses when determining its unit cost.

### Lot-aware adjustments require application actions

The inventory screen's **Adjust Stock** form records a material-level movement. It does not select a lot. Adding 250 g there can increase the material's total stock while leaving no available lot for batch completion to consume.

Lot-aware adjustments are available through application actions, for example in a self-hosted instance's IEx console. After obtaining an authorized staff/admin `actor` and the blend `material`, an output receipt looks like:

```elixir
lot =
  Ash.create!(
    Craftplan.Inventory.Lot,
    %{
      lot_code: "BLEND-2026-10-07-001",
      material_id: material.id,
      received_quantity: Decimal.new("250"),
      received_at: DateTime.utc_now()
    },
    actor: actor
  )

Craftplan.Inventory.adjust_stock!(
  %{
    material_id: material.id,
    lot_id: lot.id,
    quantity: Decimal.new("250"),
    reason: "Manual blend output BLEND-2026-10-07-001"
  },
  actor: actor
)
```

Creating the lot alone does not add stock: the positive movement does. Record each input deduction with the same `adjust_stock!` action, its input `material_id` and `lot_id`, a negative quantity, and the blend run identifier in the reason. Check available input stock before recording the run. These individual actions do not constitute an atomic production workflow; reconcile partial records if one fails.

### Traceability limits of this workaround

A finished batch can be traced to the consumed **blend material lot**. The manual input movements and their notes do not create a machine-readable production link from that lot to its raw-material input lots. Keep the run record outside the Trace Center to bridge that gap. Do not rely on the automatic recall report to find all affected finished batches from a raw ingredient used in a manually produced blend.

## What automatic intermediate production would need

A complete feature would consume input lots, create the intermediate output lot, record its actual yield and cost, and link the input and output records in one production operation. Finished recipes would then consume that stocked intermediate. Multi-stage forward/backward tracing and recall reports would need to follow those links.

This workflow is not currently implemented, and no release date is promised. See [issue #50](https://github.com/puemos/craftplan/issues/50) for the usage discussion.
