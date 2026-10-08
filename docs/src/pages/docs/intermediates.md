---
layout: ../../layouts/DocsLayout.astro
title: Intermediate Production
description: Make and stock intermediate materials with actual yield, lot costs, and complete traceability
---

Make a material once, stock it, and use that stock across finished products. Each completed batch preserves its actual yield, costs, input lots, and recipe history.

**New workflow:** requires a build that includes native material production.

## Watch the walkthrough

A 2-minute walkthrough with on-screen explanations and no audio. The recording shows the complete workflow in an earlier layout; screenshots below show the latest interface.

<video controls playsinline preload="metadata" poster="/craftplan/native-intermediates/production.webp" aria-label="Native intermediate production walkthrough" class="w-full rounded-xl border border-stone-200 bg-stone-50">
  <source src="/craftplan/native-intermediates/demo.mp4" type="video/mp4" />
</video>

<p class="flex flex-wrap gap-4">
  <a href="/craftplan/native-intermediates/craftplan-native-intermediates-demo.zip" download>Download everything — video, screenshots, and offline guide</a>
</p>

## Three steps

1. **Define the recipe.** Open a material's **Production** tab. Add input materials, quantities, and a standard yield using the editable table, then save.
2. **Plan the batch.** Select **Make batch** and enter the amount to make. Quantities scale automatically. Review suggested lots; use **Change lot** or **Split across lots** when needed.
3. **Record and stock.** Select **Record result**. Enter usable output and actual ingredient usage. Review cost and optional lot details, then select **Complete & stock**. Stock changes only at completion; **Back** preserves your entries.

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/record-result.webp" width="1280" height="720" alt="Record result step with 950 g actual yield, ingredient quantities and a concise summary of output stock, input cost and 95 percent yield" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">Actual yield and usage stay visible; optional lot details stay folded away.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/record-result.webp" download>Download screenshot</a></p>
</figure>

## What stays connected

- Finished products consume the intermediate's stocked lot. Raw inputs are consumed once.
- Actual input costs determine the output lot's unit cost. New recipes apply to future runs; completed runs retain their original recipe.
- Trace supplier lots forward to products and customer orders, or finished batches back to their source lots.
- Insufficient stock rejects completion without creating output stock.

**Example:** $4.40 of inputs yields 950 g of blend, costing $4.63/kg. A loaf uses 400 g and a roll uses 100 g, leaving 450 g.

<details>
  <summary class="cursor-pointer font-semibold">Recipe, planning, and history screenshots</summary>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/recipe-inputs.webp" width="1280" height="720" alt="Recipe editor with Material and Quantity table columns, flat editable inputs, gram unit labels, and Remove actions" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">Input materials use the same editable table style as product recipes.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/recipe-inputs.webp" download>Download screenshot</a></p>
</figure>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/plan-batch.webp" width="1280" height="720" alt="Plan batch step with one planned amount, two scaled ingredient quantities, automatically selected lots and optional Change lot controls" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">Plan the amount; inspect lot controls only when you need them.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/plan-batch.webp" download>Download screenshot</a></p>
</figure>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/production.webp" width="904" height="1192" alt="Daily Flour Blend production page showing 450 g remaining, the current version 3 recipe, and the completed version 2 batch with 950 g yield and its actual input lots" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">A compact stock summary and ingredient table sit above history. Expand a batch for its yield, cost, and input lots.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/production.webp" download>Download screenshot</a></p>
</figure>

</details>

<details>
  <summary class="cursor-pointer font-semibold">Tracing and stock validation screenshots</summary>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/forward-trace.webp" width="1328" height="1796" alt="Forward trace from the wheat supplier lot through the produced Daily Flour Blend lot to the loaf and roll batches and their customer orders" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">A raw supplier lot reaches both finished products through the intermediate production link.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/forward-trace.webp" download>Download screenshot</a></p>
</figure>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/backward-trace.webp" width="1058" height="1523" alt="Backward trace of the loaf showing its Daily Flour Blend ingredient lot and the wheat and rye supplier lots used to produce that blend" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">The loaf traces back to the blend's actual input lots.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/backward-trace.webp" download>Download screenshot</a></p>
</figure>

<figure class="not-prose my-8">
  <img src="/craftplan/native-intermediates/stock-validation.webp" width="1058" height="914" alt="Make batch form rejecting a request for 1,300 g of wheat from a lot with only 1,200 g available" loading="lazy" decoding="async" class="w-full rounded-xl border border-stone-200 bg-stone-50 shadow-sm" />
  <figcaption class="mt-3 text-center text-sm text-stone-500">The failed attempt preserves the 450 g of existing blend stock.</figcaption>
  <p class="mt-2 text-center text-sm"><a href="/craftplan/native-intermediates/stock-validation.webp" download>Download screenshot</a></p>
</figure>

</details>

Input quantities in ancestor tracing describe the whole intermediate batch. Allergens and nutritional facts remain maintained separately. All demo media uses an isolated local database with demonstration data.
