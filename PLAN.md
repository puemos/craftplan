Craftday Product Plan — D2C Micro Manufacturing (Self‑Hosted)

Last updated: 2025‑10‑11

Progress
- Overall: [ ] Not started / [x] In progress / [ ] Done
- Milestones
  - [ ] M1: Orders & Checkout Essentials (in progress)
  - [ ] M2: Catalog & Inventory Basics
  - [ ] M3: Make Sheet & Batches (in progress)
  - [ ] M4: Data IO & Payments
  - [ ] M5: BI & Insights
  - [ ] M6: Overview Tabs Across Index Pages

Recently Completed
- Production split into tabs: Overview and Schedule; Schedule shows calendar only.
- Planner highlights over‑capacity days; metrics computed in Overview with details modal.
- Make Sheet print‑only layout improved; print view hides nav/actions.
- Product capacity: `max_daily_quantity` field added and enforced at checkout; global capacity validation.
- Product availability gating in storefront.
- Settings extended for tax/fulfillment/lead‑time/daily capacity/shipping; checkout totals preview uses Settings.
- Invoice printable page (HTML) scaffold; browser print supported.
- Seeds updated for settings, capacities, availability; FK ordering fixed.

Next Up
- Production Overview: ensure `overview_tables` and `days_range` are always assigned before render; recompute on state changes.
- Overview rows: click to jump to Schedule (focus a day); add highlight on target day.
- Schedule Day view: verify prev/next behavior limits to a single day; polish headers.
- PDF: optional ChromicPDF integration for invoices (server‑side) while keeping HTML fallback.
- Lint/polish: remove unused helpers in PlanLive; fix quoted atom warning in Checkout; audit print classes.
- Add Overview tab to other index pages (Products, Inventory, Orders, Customers, Purchasing) with quick metrics.

How To Track
- Check off tasks below as you complete them. Keep milestone checkboxes in sync.
- Optionally add completion dates, e.g., [x] … (2025‑10‑11).

Purpose
- Keep Craftday incredibly simple for D2C micro manufacturers: Sell → Make → Stock.
- Ship small, durable primitives; avoid configuration sprawl.
- Optimize for solo/small teams, mobile-friendly flows, and clarity over features.

Guiding Principles
- One obvious way to do things; defaults on; minimal toggles.
- Recipe-driven production; batches optional; simple costing; daily capacity.
- Self-hosted friendly: works offline/manual; integrations are optional.

Milestones Overview
- M1: Orders & Checkout Essentials (invoices, tax mode, discounts, delivery/pickup, availability)
- M2: Catalog & Inventory Basics (variants, simple unit conversions, low stock + reorders)
- M3: Make Sheet & Batches (daily production, consume all, batch code, labels, order status page)
- M4: Data IO & Payments (CSV import/export, optional Stripe, stock gating)
- M5: BI & Insights (capacity utilization, sales trends, inventory KPIs)
- M6: Overview Tabs Across Index Pages (consistent Overview for key sections)

Legend
- Domain = Ash Resource/Domain work
- UI = LiveView/UI changes
- Ops = Services/Emails/PDF/CSV/etc.

--------------------------------------------------------------------
Milestone 1 — Orders & Checkout Essentials (2 weeks)
Status: [ ] Not started  [x] In progress  [ ] Done
Goals
- Create and collect: simple invoices (PDF), mark paid; single tax mode; order-level discounts.
- Delivery vs pickup with lead time and daily capacity; product availability flags.

User Stories (MVP)
- As a seller, I generate an invoice PDF and mark an order as paid with a method/date.
- As a seller, I set a single tax rate and apply it to orders automatically.
- As a seller, I apply a simple discount to an order.
- As a customer, I select pickup or delivery; delivery dates enforce lead time/capacity.
- As a seller, I toggle product availability (available/preorder/off) without complexity.

Requirements
- Domain
  - Orders
    - [ ] Add attributes: `invoice_number`, `invoice_status`, `invoiced_at`, `payment_method`, `discount_type`, `discount_value`, `delivery_method`.
    - [x] Calculate totals: compute `discount_total` and `tax_total` from Settings (logic in place; discount UI pending).
  - Settings
    - [x] Add `tax_mode`, `tax_rate`, `offers_pickup`, `offers_delivery`, `lead_time_days`, `daily_capacity`, `shipping_flat`.
  - Catalog
    - [x] Add `selling_availability` on `Catalog.Product`.
- Product Capacity
  - [x] Add `max_daily_quantity` (0 = unlimited) to `Catalog.Product`.
  - [x] Enforce per‑product capacity at checkout for the selected delivery date.
  - [ ] Optionally show capacity hint on product page (earliest available date is future scope).
- UI
  - [x] Checkout: delivery method and date validator (lead time, per‑product and global capacity).
  - [ ] Checkout: tax and discount lines UI (logic wired; discount UI pending).
  - [x] Settings: extend General tab for tax/fulfillment/capacity/lead time/shipping.
  - [x] Product: availability control in form/show.
  - [x] Product: input for `max_daily_quantity` and surface on details when > 0.
- Ops
  - [x] Invoice HTML printable page (browser print).
- Seeds
  - [x] Update `priv/repo/seeds.exs` to set Settings (tax_mode, tax_rate, lead_time_days, daily_capacity, shipping_flat).
  - [x] Update product seeds to set `selling_availability` and `max_daily_quantity` for a few items.
  - [x] Add a note in README/PLAN on running: `mix ecto.reset && mix run priv/repo/seeds.exs` (or `mix ecto.migrate && mix run priv/repo/seeds.exs`).

Acceptance Criteria
- Can issue invoice for an order: see PDF, status becomes `issued`; marking paid updates totals and `paid_at`.
- Tax calculation matches Settings: inclusive vs exclusive; discount applied pre- or post-tax per simple rule (exclusive mode: subtotal → discount → tax; inclusive mode: price includes tax, show derived tax component).
- Checkout enforces delivery date availability and capacity; pickup requires no date if disabled.
- Products with `selling_availability:off` cannot be added to cart; `preorder` allowed but flagged.

Implementation Approach (files)
- Domain (Ash)
  - Orders
    - `lib/craftday/orders/order.ex`
      - Add attributes listed above; wire to `create`/`update` `accept` lists.
      - Keep `reference` logic as-is.
    - `lib/craftday/orders/changes/calculate_totals.ex`
      - Extend to include discount and tax per Settings; populate `discount_total`, `tax_total`, `total` consistently.
  - Settings
    - `lib/craftday/settings/settings.ex`
      - Add new attributes; expose via General Settings UI.
  - Catalog Product
    - `lib/craftday/catalog/product.ex`
      - Add `selling_availability` attribute with default `:available`.
- UI
  - Settings
    - `lib/craftday_web/live/settings_live/index.ex`
    - `lib/craftday_web/live/settings_live/form_component.ex`
      - Add fields for tax and fulfillment options.
  - Product
    - `lib/craftday_web/live/manage/product_live/form_component.ex`
    - `lib/craftday_web/live/manage/product_live/show.ex`
      - Add selling availability control and display.
  - Checkout
    - `lib/craftday_web/live/public/checkout_live/index.ex`
      - Form: `delivery_method`, date picker constraints; show tax/discount lines (UI pending for discount); trigger invoice issue on place order when configured.
      - Implement capacity check by counting orders with `delivery_date` per day and comparing to `Settings.daily_capacity` and product `max_daily_quantity`.
  - Storefront Catalog/Cart
    - `lib/craftday_web/live/public/catalog_live/index.ex`
    - `lib/craftday_web/live/public/catalog_live/show.ex`
      - Hide “Add to cart” for `off`; display “Preorder” badge for `preorder`.
  - Ops (PDF)
  - Add `Invoices` module: `lib/craftday/orders/invoices.ex` with functions to render HTML and emit PDF using ChromicPDF (behind config).
  - Add route to download invoice PDF: `GET /manage/orders/:reference/invoice` (controller or LiveView event streaming binary).

Data & Migration Checklist
- Orders: add columns for invoice/discount/delivery fields.
- Settings: add tax/fulfillment/capacity fields.
- Catalog products: add selling_availability.


--------------------------------------------------------------------
Milestone 2 — Catalog & Inventory Basics (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Single-dimension variants; simple unit conversion UX; low-stock and reorder suggestions.

User Stories
- As a seller, I offer one option per product (e.g., size) with price delta and auto-SKU.
- As a seller, I input quantities in kg/l UI but store in g/ml; see readable units.
- As a seller, I get a low-stock list and a simple reorder suggestion list.

Requirements
- Domain
  - Variants
    - [ ] New resource: `Catalog.ProductVariant` (fields: `product_id`, `value`, `sku`, `price_delta`, `active`).
    - [ ] Product carries `option_name` (e.g., “Size”).
  - Inventory
    - [x] No change to units storage (base units: gram/ml/piece). Conversions are a UI concern.
  - Purchasing
    - [x] Reorder suggestions are computed, not persisted.
- UI
  - [ ] Product Show/Forms: Variants tab with CRUD.
  - [ ] Storefront product page: choose variant; price = base + delta.
  - [ ] Inventory Index: low-stock banner and “Reorder Suggestions” view.
- Ops
  - None required beyond recomputations.

Acceptance Criteria
- Creating variants generates default SKU suggestions (`<SKU>-<VALUE>`), editable.
- Storefront correctly prices by variant and uses variant SKU in cart/order items.
- Low-stock banner shows materials where `current_stock < minimum_stock`.
- Reorder list shows suggested quantity and link to create PO (navigates to Purchasing with supplier selection).

Implementation Approach (files)
- Domain
  - `lib/craftday/catalog/product.ex`: add `option_name`.
  - Add `lib/craftday/catalog/product_variant.ex` + wire into `lib/craftday/catalog.ex` domain.
  - Orders: `lib/craftday/orders/order_item.ex`: add optional `variant_id` and store `unit_price` as base + delta.
- UI
  - Product Variants
    - New LV(s): `lib/craftday_web/live/manage/product_live/variants_component.ex` used under Product Show.
  - Storefront
    - `lib/craftday_web/live/public/catalog_live/show.ex`: variant selector; add-to-cart carries variant.
  - Inventory
    - `lib/craftday_web/live/manage/inventory_live/index.ex`: compute low stock server-side and show banner.
    - New LV: `ReorderLive.Index` or a tab under Inventory to show suggestions using `InventoryForecasting`.
- Services
  - Extend `InventoryForecasting` to compute shortages vs min/max and upcoming orders.

Data & Migration Checklist
- Add `catalog_product_variants` table; add `option_name` to products; add `variant_id` to order items.


--------------------------------------------------------------------
Milestone 3 — Make Sheet & Batches (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- “Today’s Make Sheet” that aggregates quantities; one-click “Consume all”; optional batch code; basic label PDFs.
- Public order status page.

User Stories
- As a maker, I see today’s production quantities per product with order links; I can mark items done and consume materials in one shot.
- As a maker, I generate batch code automatically for items and print a simple product label with ingredients/allergens.
- As a customer, I view my order status by reference without logging in.

Requirements
- Domain
  - Orders
    - [ ] Add optional `batch_code` on `OrderItem`.
- UI
  - [x] Production: add “Make Sheet” print‑friendly view.
  - [ ] Production: add “Consume All”.
  - [x] Capacity: highlight product/day cells that exceed `max_daily_quantity` in planner.
  - [x] Remove metrics and details modal from Schedule tab (Overview only).
  - [ ] Click row in Overview to jump to Schedule for that day (and highlight target day).
  - [ ] Ensure `days_range` is always assigned in mount/handle_params; recompute `overview_tables` on relevant state changes to avoid KeyErrors.
  - [ ] Schedule Day view polish: prev/next adjust by 1 day; headers/body limit to single day.
  - Labels
    - [ ] Product label PDF (ingredients/allergens/batch/date).
  - Public Order Status
    - [ ] New LV `/o/:reference` shows status, delivery date, items.
- Ops
  - [ ] PDF rendering reused from M1.
  - [ ] “Consume All” uses existing `Orders.Consumption`.

Acceptance Criteria
- Make Sheet shows per-product totals for selected day; “Consume All” updates material stocks.
- When marking item done, batch code is set (e.g., `B-YYYYMMDD-SKU`); can be edited.
- Label PDF renders ingredients/allergens from recipe; includes batch code if present.
- Public status page resolves by order reference with no auth.

Implementation Approach (files)
- Domain
  - `lib/craftday/orders/order_item.ex`: add `batch_code` attribute; default generator in code when status becomes `:done`.
  - `lib/craftday/orders/consumption.ex`: no change; reuse.
- UI
  - `lib/craftday_web/live/manage/plan_live/index.ex`: add “Make Sheet” mode, print view, bulk actions; wire Overview/Schedule tabs; compute and guard assigns.
  - New controller or LV endpoint for Label PDF: `/manage/products/:sku/label` and `/manage/orders/:ref/label`.
  - New LV `CraftdayWeb.Public.OrderStatusLive` (route `/o/:reference`).
- Ops
  - Add label templates (HEEx -> PDF via ChromicPDF). Ingredients come from `product.recipe.components`.

Data & Migration Checklist
- Add `batch_code` to `orders_items`.


--------------------------------------------------------------------
Milestone 4 — Data IO & Payments (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- CSV import/export for key entities; optional Stripe checkout link; storefront stock gating.

User Stories
- As a seller, I import products/materials/recipes/customers via CSV; I export orders/customers/movements.
- As a seller, I enable Stripe and redirect to a secure checkout link after order creation.
- As a seller, I optionally block orders for products marked unavailable or over capacity.

Requirements
- CSV
  - Import endpoints for Products, Materials, Recipes (2-phase: create products/materials first; recipes reference by SKU), Customers.
  - Exports for Orders, Customers, Inventory Movements.
  - Use NimbleCSV; show dry-run and errors.
- Payments (optional)
  - [ ] Settings: `stripe_public_key`, `stripe_secret_key`, `stripe_enabled`.
  - [ ] Checkout: create Stripe Checkout Session and redirect when enabled.
- Stock Gating
  - [ ] Gate by `daily_capacity` and `selling_availability`.

--------------------------------------------------------------------
Milestone 5 — BI & Insights (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done

Goals
- Provide lightweight, actionable insights without heavy configuration.

User Stories
- As a maker, I see capacity utilization by product and day; I can spot over‑capacity days.
- As a seller, I see sales trends and top products/customers for a selected period.
- As an operator, I see basic inventory KPIs: days of supply and low‑stock items.

Requirements
- Views
  - [ ] Capacity Utilization: per product/day % = scheduled quantity / max_daily_quantity; flag over 100%.
  - [ ] Sales Trends: revenue and orders by day/week; top products/customers.
  - [ ] Inventory KPIs: low stock list; days of supply using recent consumption.
- UI
  - [ ] Add `/manage/reports` LiveView grouping these tiles/tables (reuse DataVis components).
  - [ ] Date range picker; default last 30 days.
- Data
  - [ ] Query functions in a `Craftday.Insights` context (no persistence) or use SQL with aggregates.
  - [ ] Capacity pulls from Orders+Products; Sales from Orders; Inventory from Inventory+Forecasting.
 - Interactions
   - [ ] Each metric tile/table row is clickable to drill into detail (consistent with Overview behavior).

Acceptance Criteria
- BI page loads quickly and works without extra config; shows empty‑state hints when data missing.
- Over‑capacity days are clearly highlighted.

Implementation Approach (files)
- New context: `lib/craftday/insights.ex` for query helpers.
- New LV: `lib/craftday_web/live/manage/reports_live/index.ex` and routes under `/manage`.
- Reuse `CraftdayWeb.Components.DataVis` for stat cards and tables.

--------------------------------------------------------------------
Milestone 6 — Overview Tabs Across Index Pages (1–2 weeks)
Status: [ ] Not started  [x] In progress  [ ] Done

Goals
- Provide a consistent “Overview” tab with quick metrics across key index pages; keep details under existing tabs.

Pages
- Products, Inventory, Orders, Customers, Purchasing.

User Stories
- As a user, I land on an Overview tab showing key KPIs and quick links.
- I can click a metric to see the underlying list filtered to that segment.

Requirements
- [ ] Add tabs to each index page: Overview (default) + existing content under secondary tabs.
- [ ] Define 3–5 stat cards + 1–2 tables per page (e.g., low stock, pending orders, top customers, open POs).
- [ ] Make rows/tiles clickable to navigate to the relevant filtered list.

Implementation Approach (files)
- Products: `lib/craftday_web/live/manage/product_live/index.ex`
- Inventory: `lib/craftday_web/live/manage/inventory_live/index.ex`
- Orders: `lib/craftday_web/live/manage/order_live/index.ex`
- Customers: `lib/craftday_web/live/manage/customer_live/index.ex`
- Purchasing: `lib/craftday_web/live/manage/purchasing_live/index.ex`

Acceptance Criteria
- All listed pages have an Overview tab with fast‑loading metrics; clicking navigates to the correct filtered list.

--------------------------------------------------------------------
Seeding & Local Run
- After code/migrations, set up and seed with:
  - mix ecto.reset && mix run priv/repo/seeds.exs
  - or: mix ecto.migrate && mix run priv/repo/seeds.exs
- Seeds configure:
  - Settings: currency USD, tax 10% exclusive, pickup/delivery on, lead time 1 day, daily capacity 25, flat shipping 5.00.
  - Products: sample capacities and availability (some preorder/off) to exercise gating.
  - Orders: past, current, and future delivery dates for planner and forecasting.

Acceptance Criteria
- CSV import validates and provides a preview; successful rows create/update records; errors listed.
- Order creation can redirect to Stripe when enabled; payment success webhook can be added later (out of scope for MVP).
- Enabling stock gating prevents choosing unavailable dates.

Implementation Approach (files)
- CSV
  - New controllers: `CraftdayWeb.CSVController` (or LiveViews under Settings) for import/export pages.
  - Services: `lib/craftday/csv/importers/*.ex` and `exporters/*.ex` using NimbleCSV.
- Payments
  - `lib/craftday_web/live/public/checkout_live/index.ex`: branch to Stripe session creation (use `stripity_stripe`) when enabled.
- Settings
  - Extend Settings resource and UI with Stripe keys and gating flag.

Data & Migration Checklist
- Add Settings fields for Stripe.


--------------------------------------------------------------------
Cross-Cutting Notes
- Taxes & Totals
  - Keep rules simple; document clearly in README and Guides.
- Internationalization
  - Continue using Money for currency; tax display mirrors mode (inclusive/exclusive).
- PDFs
  - Prefer ChromicPDF for reliability; add config guard so app runs without it (fallback to HTML print).
- Security
  - Keep public order status read-only; no PII beyond order items and delivery date.
- Backward Compatibility
  - New fields defaulted; migrations written with safe defaults; ensure existing data loads.

Polish & Cleanup
- [ ] Remove unused helpers in `lib/craftday_web/live/manage/plan_live/index.ex` (e.g., `get_previous_week_range/1`, `get_next_week_range/1`) if no longer used.
- [ ] Fix quoted atom warning in `lib/craftday_web/live/public/checkout_live/index.ex` (replace `form[:"delivery_method"]` with `form[:delivery_method]`).
- [ ] Audit print view classes (`print:hidden`, `print:block`) across invoice and make sheet to ensure clean output.

Open Questions
- Do we need per-item tax override now or later? (Recommend later.)
- Do we want to persist invoice PDFs or generate on demand? (Recommend on-demand for simplicity.)
- For variants, do we track inventory by variant? (Out of scope; product-level only for now.)

Task Breakdown (high-level)
- M1
  - Orders: fields + CalculateTotals updates (domain)
  - Settings: tax/fulfillment; UI forms
  - Checkout: delivery method/date/tax/discount; capacity checks; invoice issue
  - PDF: invoice render + download route
  - Product: availability field + UX
- M2
  - Variants: resource, product option name, order item variant_id
  - Product UI: variants CRUD; storefront selector
  - Inventory: low stock banner + reorder suggestions tab
- M3
  - Make Sheet: PlanLive enhancements; print view; bulk consume
  - Batch code on order items; label PDF
  - Public order status LiveView
- M4
  - CSV import/export pages + services
  - Optional Stripe toggle and redirect
  - Stock gating enforcement

Validation Plan
- Add targeted tests where patterns exist (domain changes and CalculateTotals logic).
- Manually verify flows in dev with seeded data; add sample seeds per vertical later.
 - Tests to add
   - [ ] Integration: checkout capacity validation (per‑product, global; lead time).
   - [ ] Unit: CalculateTotals (exclusive vs inclusive tax; fixed vs percent discounts).
   - [ ] Planner metrics: correctness of `compute_week_metrics/…` and details generation (edge cases: zero caps/data).
   - [ ] UI: Schedule Week/Day toggle boundaries and navigation.

Done means
- Code merged with migrations; guides updated; README features matrix updated; screenshots refreshed where relevant.
