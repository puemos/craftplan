Craftplan Product Plan — Bakery Operations (Self‑Hosted)

Last updated: 2025‑10‑18

Progress
- Overall: [ ] Not started / [x] In progress / [ ] Done
- Milestones
  - [ ] M1: Bakery Ops Essentials (in progress)
  - [ ] M2: Inventory & Purchasing Basics
  - [ ] M3: Data IO & Onboarding
  - [ ] M4: Storefront & Payments (Optional)
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
- Finish operational polish for bakery:
  - Public Order Status page at `/o/:reference` with reference, delivery/pickup date, and items.
  - Product Label print view (ingredients/allergens/batch/date) leveraging invoice print pattern.
  - Audit print classes across Make Sheet and Invoice.
- Cleanup: remove unused helpers in PlanLive; confirm navigation/highlight behaviors.
- Prep onboarding: scaffold CSV import (Products/Materials/Customers) with dry‑run and errors.

How To Track
- Check off tasks below as you complete them. Keep milestone checkboxes in sync.
- Optionally add completion dates, e.g., [x] … (2025‑10‑11).

Purpose
- Keep Craftplan incredibly simple for small bakeries: Operate → Make → Stock.
- Optimize the back‑office: production planning, materials consumption, reordering, labeling.
- Ship small, durable primitives; avoid configuration sprawl. Self‑host first.

Vertical Focus
- Primary: Bakery (preorders/pickups, daily capacity, recipe/batch workflows).

Guiding Principles
- One obvious way to do things; defaults on; minimal toggles.
- Recipe-driven production; batches optional; simple costing; daily capacity.
- Self-hosted friendly: works offline/manual; integrations are optional.

Milestones Overview
- M1: Bakery Ops Essentials (production planner, make sheet, consume, labels, invoices)
- M2: Inventory & Purchasing Basics (low stock + reorders, forecasting surface)
- M3: Data IO & Onboarding (CSV import/export, seeded bakery demo)
- M4: Storefront & Payments (Optional: basic checkout, Stripe)
- M5: BI & Insights (capacity utilization, sales trends, inventory KPIs)
- M6: Overview Tabs Across Index Pages (consistent Overview for key sections)

Legend
- Domain = Ash Resource/Domain work
- UI = LiveView/UI changes
- Ops = Services/Emails/PDF/CSV/etc.

--------------------------------------------------------------------
Milestone 1 — Bakery Ops Essentials (2 weeks)
Status: [ ] Not started  [x] In progress  [ ] Done
Goals
- Operate the bakery day‑to‑day: plan production, make, consume materials, label batches, and reconcile orders.
- Keep checkout optional; prioritize back‑office order entry and fulfillment.

User Stories (MVP)
- As a maker, I see today’s production quantities and can mark items done, then “Consume All Completed”.
- As a maker, I print simple product labels (HTML) with ingredients/allergens and optional batch code.
- As an operator, I generate an invoice (HTML print) and mark an order as paid with a method/date.
- As an operator, I set a single tax rate and daily capacity; lead time applies to deliveries.
- As a customer, I can view my order status by reference (no login).

Requirements
- Domain
  - Orders
    - [ ] Add attributes: `invoice_number`, `invoice_status`, `invoiced_at`, `payment_method`, `discount_type`, `discount_value`, `delivery_method`.
    - [x] Calculate totals: compute `discount_total` and `tax_total` from Settings (logic in place; discount UI pending).
    - [ ] Add optional `batch_code` on `OrderItem` (auto‑generate when marking done: `B-YYYYMMDD-SKU`).
  - Settings
    - [x] Add `tax_mode`, `tax_rate`, `offers_pickup`, `offers_delivery`, `lead_time_days`, `daily_capacity`, `shipping_flat`.
  - Catalog
    - [x] Add `selling_availability` on `Catalog.Product`.
- Product Capacity
  - [x] Add `max_daily_quantity` (0 = unlimited) to `Catalog.Product`.
  - [x] Enforce per‑product capacity at checkout/day scheduling.
- UI (Back‑office focus)
  - Production Planner / Make Sheet
    - [x] “Make Sheet” print‑friendly view.
    - [x] “Consume All Completed” action.
    - [x] Click rows in Overview to jump to Schedule day and highlight target day.
    - [x] Ensure `days_range` is assigned; prev/next in Day view adjusts by 1 day.
  - Labels
    - [x] Product label HTML print view (ingredients/allergens/batch/date).
  - Public Order Status
    - [x] New LV `/o/:reference` shows status, delivery date, items.
  - Checkout (optional for v0.1)
    - [x] Delivery method and date validator (lead time, per‑product and global capacity).
    - [ ] Discount line UI (logic in place; UI pending).
  - Settings & Product
    - [x] General tab for tax/fulfillment/capacity/lead time/shipping.
    - [x] Product: availability control and `max_daily_quantity` input.
- Ops
  - [x] Invoice HTML printable page (browser print).
- Seeds
  - [x] Update settings, capacities, availability; include bakery‑specific samples.

Acceptance Criteria
- Make Sheet shows per‑product totals for selected day; “Consume All Completed” updates stocks.
- Invoice print view; marking paid updates `paid_at` and payment method.
- Delivery dates enforce lead time/capacity; pickup/delivery aligned to Settings.
- Public order status resolves by reference with no auth.

Implementation Approach (files)
- Domain
  - `lib/craftplan/orders/order.ex`: ensure invoice/discount/delivery fields accept lists; add `batch_code` on order items.
  - `lib/craftplan/orders/changes/calculate_totals.ex`: totals logic as implemented; add discount UI later.
  - `lib/craftplan/orders/consumption.ex`: reuse for “Consume All”.
- UI
  - `lib/craftplan_web/live/manage/plan_live/index.ex`: Make Sheet/Overview/Schedule wiring, bulk actions, guards.
  - New LV endpoint(s) for Label print: `/manage/products/:sku/label` and/or `/manage/orders/:ref/label`.
  - New LV `CraftplanWeb.Public.OrderStatusLive` (route `/o/:reference`).
- Data & Migration Checklist
  - Orders: add invoice/discount/delivery fields; add `batch_code` to order items.


--------------------------------------------------------------------
Milestone 2 — Inventory & Purchasing Basics (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Low‑stock awareness and simple reordering; surface materials requirements from upcoming orders.

User Stories
- As a maker, I see low‑stock materials and a reorder suggestion list.
- As an operator, I can raise POs and receive into stock to unblock production.

Requirements
- Inventory
  - [x] No change to units storage (base units: gram/ml/piece). Conversions are a UI concern.
  - [ ] Inventory Index: low‑stock banner and “Reorder Suggestions” view.
- Purchasing
  - [x] Reorder suggestions are computed, not persisted.
  - [ ] Quick create PO flow from suggestions (navigates to Purchasing with supplier selection).
- Variants
  - [ ] Defer or implement only if needed for bakery (single‑dimension). Not required for v0.1 operations.

Acceptance Criteria
- Low‑stock banner shows materials where `current_stock < minimum_stock`.
- Reorder list shows suggested quantity and link to create PO.

Implementation Approach (files)
- UI
  - `lib/craftplan_web/live/manage/inventory_live/index.ex`: compute low stock server‑side and show banner.
  - New LV/tab: Reorder Suggestions under Inventory using `InventoryForecasting`.
- Services
  - Extend `InventoryForecasting` to compute shortages vs min/max and upcoming orders.

Data & Migration Checklist
- None beyond UI/services; leverage existing inventory/purchasing resources.


--------------------------------------------------------------------
Milestone 3 — Data IO & Onboarding (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Painless onboarding for bakeries: CSV import/export for key entities and a seeded demo.

User Stories
- As an operator, I import products/materials/recipes/customers via CSV with dry‑run and clear errors.
- As an operator, I export orders/customers/movements for bookkeeping.
- As a prospect, I can run a seeded bakery demo and see the full Operate → Make → Stock loop.

Requirements
- CSV
  - Import endpoints for Products, Materials, Recipes (2‑phase: create products/materials first; recipes reference by SKU), Customers.
  - Exports for Orders, Customers, Inventory Movements.
  - Use NimbleCSV; show dry‑run and errors.
- Demo
  - Seeded bakery dataset; screenshots and quick video script.

Implementation Approach (files)
- CSV
  - New LiveViews under Settings or a `CraftplanWeb.CSVController` for import/export pages.
  - Services: `lib/craftplan/csv/importers/*.ex` and `exporters/*.ex` using NimbleCSV.
- Seeds
  - Expand `priv/repo/seeds.exs` to include bakery‑specific products/recipes/orders.

Data & Migration Checklist
- None beyond seeds and CSV services.


--------------------------------------------------------------------
Milestone 4 — Storefront & Payments (Optional, 2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Optional public checkout flow and Stripe redirect for teams that sell online.

User Stories
- As a seller, I enable Stripe and redirect to a secure checkout link after order creation.
- As a seller, I optionally block orders for products marked unavailable or over capacity.

Requirements
- Payments (optional)
  - [ ] Settings: `stripe_public_key`, `stripe_secret_key`, `stripe_enabled`.
  - [ ] Checkout: create Stripe Checkout Session and redirect when enabled.
- Stock Gating
  - [ ] Gate by `daily_capacity` and `selling_availability` on the storefront.

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
  - [ ] Query functions in a `Craftplan.Insights` context (no persistence) or use SQL with aggregates.
  - [ ] Capacity pulls from Orders+Products; Sales from Orders; Inventory from Inventory+Forecasting.
 - Interactions
   - [ ] Each metric tile/table row is clickable to drill into detail (consistent with Overview behavior).

Acceptance Criteria
- BI page loads quickly and works without extra config; shows empty‑state hints when data missing.
- Over‑capacity days are clearly highlighted.

Implementation Approach (files)
- New context: `lib/craftplan/insights.ex` for query helpers.
- New LV: `lib/craftplan_web/live/manage/reports_live/index.ex` and routes under `/manage`.
- Reuse `CraftplanWeb.Components.DataVis` for stat cards and tables.

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
- Products: `lib/craftplan_web/live/manage/product_live/index.ex`
- Inventory: `lib/craftplan_web/live/manage/inventory_live/index.ex`
- Orders: `lib/craftplan_web/live/manage/order_live/index.ex`
- Customers: `lib/craftplan_web/live/manage/customer_live/index.ex`
- Purchasing: `lib/craftplan_web/live/manage/purchasing_live/index.ex`

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

Setup & Packaging
- Add Dockerfile and `docker-compose` app service for one‑command setup in self‑hosted environments.

Acceptance Criteria
- CSV import validates and provides a preview; successful rows create/update records; errors listed.
- If enabled, order creation can redirect to Stripe; payment success webhook can be added later (out of scope for MVP).
- Storefront gating (if used) prevents choosing unavailable dates.

Implementation Approach (files)
- CSV
  - New controllers: `CraftplanWeb.CSVController` (or LiveViews under Settings) for import/export pages.
  - Services: `lib/craftplan/csv/importers/*.ex` and `exporters/*.ex` using NimbleCSV.
- Payments
  - `lib/craftplan_web/live/public/checkout_live/index.ex`: branch to Stripe session creation (use `stripity_stripe`) when enabled.
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
- Printing
  - Use browser print for all PDF generation (invoices, labels, make sheets); keep it simple and self-hosted friendly.
- Security
  - Keep public order status read-only; no PII beyond order items and delivery date.
- Backward Compatibility
  - New fields defaulted; migrations written with safe defaults; ensure existing data loads.

Polish & Cleanup
- [ ] Remove unused helpers in `lib/craftplan_web/live/manage/plan_live/index.ex` (e.g., `get_previous_week_range/1`, `get_next_week_range/1`) if no longer used.
- [ ] Audit print view classes (`print:hidden`, `print:block`) across invoice and make sheet to ensure clean output.

Open Questions
- Do we need per‑item tax override now or later? (Recommend later.)
- Do we want to persist invoice PDFs or generate on demand? (Recommend on‑demand for simplicity.)
- For variants, do we track inventory by variant? (Out of scope; product‑level only for now.)
- Should public storefront ship in v0.1 for bakeries, or remain optional behind config?

Task Breakdown (high-level)
- M1
  - Orders: fields + CalculateTotals updates (domain)
  - Settings: tax/fulfillment; UI forms
  - Checkout: delivery method/date/tax/discount; capacity checks; invoice issue
  - Invoice: HTML print view (already complete)
  - Product: availability field + UX
- M2
  - Inventory: low stock banner + reorder suggestions tab
  - Optional: variants only if needed for bakery
- M3
  - CSV import/export pages + services; seeded bakery demo
- M4 (Optional)
  - Stripe toggle and redirect; storefront gating

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
