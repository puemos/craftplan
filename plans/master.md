# Craftplan Product Plan -- Bakery ERP Roadmap

Last updated: 2025-11-01

## Progress Snapshot

- Overall: [ ] Not started / [x] In progress / [ ] Done
- Current Cycle (Oct 2025): Stabilize internal print flows + prep costing foundations.
- Active Initiative: Inventory Forecast Grid Milestone B (LiveView controls + metrics band).
- Milestone Health
  - [ ] M1: Production Costing Foundations
  - [ ] M2: Traceability & Compliance
  - [x] M3: Inventory Planning & Purchasing
  - [ ] M4: WhatsApp Business Integration
  - [ ] M5: Insights & Pricing Intelligence
  - [ ] M6: Onboarding & Adoption

## Recently Completed

- Planner split into Overview/Schedule tabs; schedule calendar isolates day view.
- Over-capacity highlights in planner with metrics modal across tabs.
- Make Sheet print view hides navigation and actions; invoice printable HTML scaffolded.
- Product capacity (`max_daily_quantity`) enforced at checkout alongside global capacity.
- Public storefront retired in favor of a login-first screen; capacity/tax/fulfillment settings remain for internal planning.
- CSV import LiveComponent refactor with reusable wizard, per-entity configs, and LiveView tests.
- Orders and Inventory LiveViews aligned to settings-inspired layout primitives with shared components.

## Competitive Insights -- Craftybase Highlights

- Multi-stage BOMs with components/sub-assemblies and labor costing; generates real-time cost rollups and pricing suggestions.
- Compliance and traceability tooling: lot/batch tracking, recall workflows, audit-friendly reports.
- Location-aware inventory with stock transfers, consignment tracking, and guided stocktake/cycle count tooling.
- Automated COGS calculations (GAAP/IRS aligned) feeding reports and profitability dashboards.
- Integrated channel sync (Shopify, Etsy, Square, Faire, Wix, WooCommerce, Amazon Handmade) with real-time stock updates.
- Templates and calculators (pricing, production planning) supporting onboarding and ongoing price optimization.

## Guiding Principles

- Operate -> Make -> Stock remains the primary loop; extend with costing and compliance primitives rather than bespoke workflows.
- Self-host friendly and offline tolerant: webhooks/integrations should degrade gracefully to CSV or manual sync.
- Favor declarative Ash resources and LiveView streams; keep imperative logic in services only when needed.
- Every new surface must support printable artifacts (labels, planner, invoices, compliance reports).

---

## Milestone 1 -- Production Costing Foundations

**Status:** [ ] Not started [x] In progress [ ] Done

### Goals

- Match competitor parity on multi-stage recipes, labor costing, and automated batch cost rollups.
- Provide pricing guidance hooks that later feed Insights.

### User Stories

- As a product developer, I build a BOM with components, sub-assemblies, and labor entries.
- As an operator, completing a batch generates actual cost per unit and suggested price ranges.
- As a planner, I see batch codes auto-generated when marking production done.

### Requirements

**Domain**

- [x] New Ash resources for BOM structures: `Catalog.BOM`, `Catalog.BOMComponent`, `Catalog.LaborStep` with versioning.
- [x] Link BOM to `Catalog.Product`; support status (`draft`, `active`).
- [x] Labor rates and overhead settings in `Settings` (hourly rate, markup defaults).
- [x] Batch cost calculation service generating `material_cost`, `labor_cost`, `overhead_cost`, `unit_cost`.
- [x] Auto-generate `batch_code` (`B-YYYYMMDD-SKU-SEQ`) when order items marked done; persist to order items.

**UI**

- [x] BOM editor (Recipe tab) backed by BOMs with simple mode save (creates new active version).
- [ ] Planner "Mark Done" dialog shows resulting batch code and actual cost snapshot.
- [x] Pricing helper card on product detail showing suggested retail/wholesale prices (based on markup settings).

### BOM Versioning (Switcher + History)

- [x] Add version switcher to the Product Recipe/BOM tab
  - Shows current BOM (version, status, published_at)
  - Dropdown lists all versions (vN · status · date)
  - Selecting switches the editor to that version (read-only for archived)
- [x] History table below editor
  - Columns: Version, Status, Published, Notes, Unit Cost, Actions (View, Duplicate, Make Active, Archive)
  - Read-only rendering for non-current versions
- [x] Actions
  - Duplicate → creates new draft (next version) with copied components & labor
  - Make Active → sets selected draft to active (sets published_at)
  - Archive → sets selected to archived (read-only)
- [ ] Routing
  - Support optional `?v=:version` param for preselecting a version
- [x] Tests
  - LiveView: switch versions, duplicate flow, promote to active, archive
  - Domain: duplication service copies children; promote enforces single active

### Data & Constraints for Versioning

- [ ] Enforce single active BOM per product with partial unique index
  - `unique_index(:catalog_boms, [:product_id], where: "status = 'active'", name: "catalog_boms_one_active_per_product")`
- [ ] Add `:promote` update action on `Catalog.BOM` (status -> :active, published_at -> now)
- [ ] Add duplication service `Catalog.Services.BOMDuplicate` (copy + manage_relationship)
- [ ] Ensure `AssignBOMVersion` supplies version on create (no default)
- [ ] Refresh rollups after duplicate/promote/update

**Data & Migrations**

- [x] Tables for BOMs/components/labor; migrations keep existing products unaffected until BOM assigned.
- [x] Backfill seeds with example recipes (bread, pastry) including labor.
- [x] Persisted BOM rollups (`catalog_bom_rollups`) with unique index on `bom_id`; auto-refresh on BOM/component/labor changes.
- [x] Add DB index on `catalog_bom_rollups(product_id)` to speed product cost reads.
- [x] Optional: materialized flattened components JSONB in rollups + GIN index for label/traceability queries.

**Deprecations & Removals** (no backward compatibility)

- [x] Remove legacy Recipe model usage in domain and UI
  - [x] Switch Product label ingredients to BOM components (fallback not required)
  - [x] Replace product financial calculations to prefer active BOM unit cost; remove recipe-based cost calcs
  - [ ] Remove Recipe editor UI and tabs (`ProductLive.FormComponentRecipe`, show routes/tabs)
  - [x] Remove `Catalog.Recipe` and `Catalog.RecipeMaterial` resources from `Craftplan.Catalog`
  - [x] Drop `catalog_recipes` and `catalog_recipe_materials` tables via migration
- [x] Replace `Material <-> Recipe` relationships with `Material <-> BOM` through `BOMComponent`
- [x] Update planner/forecasting to load from BOMs instead of Recipes
- [x] Update seeds/tests to use BOMs exclusively; remove recipe fixtures
- [ ] Remove any documentation and references to Recipes

### Acceptance Criteria

- Batch completion persists cost breakdown and batch code on order item; totals flow into invoices.
- Pricing helper toggles between markup types (percent/fixed) and respects inclusive/exclusive tax.
- BOM editor enforces valid graphs (no cycles) and supports saving draft vs publish.

### Recipe → BOM Migration Plan (UI Parity)

**Goal:** keep the current Recipe editor UX intact while switching the backend to BOMs (no back-compat required), then cleanly remove Recipe.

**Phase A — Adapter (UI parity on existing route)**

- [ ] Replace Recipe editor internals with BOM-backed component while preserving DOM ids, events, and layout
  - Keep route and tab labels the same for now (e.g., "Recipe") to avoid UX regression
  - Files to migrate:
    - `lib/craftplan_web/live/manage/product_live/form_component_recipe.ex`
    - `lib/craftplan_web/live/manage/product_live/show.ex`
  - Form mapping
    - Materials list -> BOM components (`component_type: :material`)
    - Add optional sub-assembly picker (`component_type: :product`)
    - Add labor steps editor (sequence, duration_minutes, rate_override)
  - Reads/writes
    - Load product `:active_bom` (or create one if missing)
    - Save components/labor via BOM create/update arguments: `components`, `labor_steps`
  - Tests
    - Keep existing selectors/ids; update test setup to create BOMs in place of Recipes

**Phase B — Domain usage switch**

- [x] Update product calculations to prefer active BOM unit cost; DB rollups first, fallback to compute or recipe only when needed
- [x] Update product label ingredients to read from BOM components; keep recipe fallback during transition
- [x] Update planner/forecast materials demand to use BOM components + rollups (remove recipe reliance)
- [x] Update consumption flows to use BOM components when completing items; align confirmation modal sources
- [x] Update seeds/fixtures to BOM only (remove recipe seeding)
  - [x] Update dev seeds to BOM-only (removed recipe seeding)

**Phase C — Cleanup and removal**

- [ ] Rename the UI tab/labels from "Recipe" to "BOM" (route may remain for continuity or be redirected)
- [x] Remove Recipe resources from domain and UI
  - Delete `Catalog.Recipe` and `Catalog.RecipeMaterial`
  - Remove LiveView recipe-specific code paths
  - Drop `catalog_recipes` and `catalog_recipe_materials` tables
- [x] Replace `Material <-> Recipe` relationship with `Material <-> BOM` through `BOMComponent`
- [ ] Update docs to refer to BOMs exclusively

**Acceptance Criteria (UI parity)**

- The editor form keeps the same structure, ids, and interactions; users can add/edit materials and see totals like before
- Sub-assemblies and labor steps are available without changing the overall layout
- Product label, pricing calcs, and planner derive data from BOMs

### Implementation Notes

- Consider `Ash.Flow` for multi-step BOM creation to reuse validations.
- Add unit tests for cost calculator (material shrinkage, multi-step components).
- Update documentation in guides for BOM/labor usage.

---

## Milestone 2 -- Traceability & Compliance

**Status:** [ ] Not started [ ] In progress [ ] Done

> ⚠️ **NEEDS FLESHING OUT** - Requires detailed data model design, UI wireframes, and acceptance test scenarios

### Goals

- Deliver lot tracking, recall readiness, and audit-friendly exports ahead of competitor parity claims.

### User Stories

- As a quality lead, I can trace which batches used a recalled material and export affected orders.
- As an operator, I can record certifications/expiry on materials and be alerted during production.
- As a regulator, I can receive printable compliance reports showing batch lineage and disposition.

### Requirements

**Domain**

- [ ] Extend inventory movements to capture `lot_number`, `expiry_date`, `certifications`.
- [ ] Batch-to-material usage join resource for trace queries.
- [ ] Recall log resource with status (`investigating`, `resolved`).

**UI**

- [ ] Traceability dashboard under `/manage/traceability` summarizing recent batches, open recalls, expiring materials.
- [ ] Batch detail view linking orders, materials, and printable compliance sheet.
- [ ] Warnings in planner when scheduled production will use expiring lots.

**Ops/Reports**

- [ ] Generate compliance export (CSV/HTML) for selected batch or date range.
- [ ] Add audit trail events for lot assignments and recall resolutions.

### Acceptance Criteria

- Given a recalled material lot, system lists all batches and orders containing it within seconds.
- Expiry warnings show within planner cards and block completion unless overridden with reason.
- Compliance exports include signature block and can be printed cleanly.

### Implementation Notes

- Add composite indexes for lot/batch lookups.
- Build LiveView stream for traceability dashboard; include empty-state messaging.
- Tests: traceability query unit tests + LiveView flow for marking recall resolved.

---

## Milestone 3 -- Inventory Planning & Purchasing

**Status:** [ ] Not started [x] In progress [ ] Done

### Goals

- Move beyond low-stock alerts to actionable purchase workflows with location awareness.

### Progress

- ✅ Forecast calculator + Ash `:owner_grid_metrics` action shipped (Milestone A per [plans/inventory_forecast_grid.md](./inventory_forecast_grid.md)).
- ✅ Milestone B kickoff: split the Usage Forecast grid from the new Reorder Planner (`/manage/inventory/forecast/reorder`), which now hosts the metrics band + service-level controls; telemetry + risk filters land next.
- 📋 LiveView + Purchasing dependencies tracked in `plans/inventory_forecast_grid.md` Next Steps section;

### Next Up

- Implement ForecastLive control defaults + event wiring, then land metrics band & right-rail glossary.
- Align Inventory Overview and Purchasing LiveViews to consume the new metrics payloads for PO creation.

### User Stories

- As a purchasing manager, I review reorder suggestions by supplier and raise a PO in one click.
- As a stock controller, I transfer inventory between locations and consignments with audit history.
- As an owner, I perform rolling stocktakes that feed accuracy metrics without shutting down operations.

### Requirements

**Inventory & Locations**

- [ ] Introduce `Inventory.Location` resource, transfer actions, and consignment tracking.
- [ ] Location revenue/expense reporting aligned with orders.
- [ ] Reorder engine considers lead time, safety stock, and upcoming production.

**UI**

- [x] Owner-facing forecast grid delivered per [plans/inventory_forecast_grid.md](./inventory_forecast_grid.md) (metrics band, controls, glossary rail, PO CTA).
- [ ] Inventory Overview tab: low-stock banner, forecast chart, reorder table grouped by supplier.
- [ ] Purchasing LiveView: PO quick-create from suggestions, status tracker.
- [ ] Stocktake workflow LiveView with guided counts (random/category/age-based selection) and variance report.

**Data & Integrations**

- [ ] Optional barcode import/export hooks for stocktakes (CSV upload now, future scanner integration).
- [ ] Seeds include multi-location scenario (main bakery + farmer's market consignment).

### Acceptance Criteria

- Reorder suggestions compute quantity with formula (forecast demand + safety stock - on hand - on order) and surface supplier.
- Forecast grid refresh stays under 200 ms server-side for 500 materials × 28-day horizon while surfacing risk state, stockout/order-by dates, and suggested PO per plan.
- Stocktake completion generates variance adjustment entries and accuracy metrics.
- Purchasing flow updates inventory upon receiving and closes suggestion.

### Implementation Notes

- Extend `InventoryForecasting` module; add tests covering location splits.
- Use LiveView streams for long reorder lists.
- Document stocktake best practices in guides.

---

## Milestone 4 -- WhatsApp Business Integration

**Status:** [ ] Not started [ ] In progress [ ] Done

> ⚠️ **NEEDS FLESHING OUT** - Requires API research, webhook design, message template specs, and conversation flow diagrams

### Goals

- Enable direct customer messaging, order taking, and catalog sharing via WhatsApp Business API
- Provide a channel-agnostic integration pattern that future commerce syncs can reuse

### User Stories

- As a bakery owner, I receive order messages via WhatsApp and convert them to Craftplan orders with validation
- As a customer service rep, I share product catalogs and availability directly in WhatsApp threads
- As an operator, I send order confirmations and ready-for-pickup notifications through WhatsApp

### Requirements

**Integration** (per `plans/whatsapp_integration.md`)

- [ ] WhatsApp Business API adapter with webhook handlers for incoming messages
- [ ] Message templates for order confirmations, status updates, and availability queries
- [ ] Catalog sync to WhatsApp Business API (products + availability)
- [ ] Two-way conversation flow: customer inquiry → order draft → confirmation → tracking
- [ ] Background jobs (Oban) for async message delivery and status tracking

**UI & Admin**

- [ ] `/manage/settings/integrations/whatsapp` config page for Business API credentials and phone number
- [ ] Message inbox LiveView showing conversations, with quick-order-creation from messages
- [ ] Template editor for customizing automated messages
- [ ] Dry-run mode for testing without sending real messages

**Security & Compliance**

- [ ] Webhook signature verification per WhatsApp requirements
- [ ] Rate limiting and message queue management
- [ ] Audit log for all sent/received messages
- [ ] Customer consent tracking for marketing messages

### Acceptance Criteria

- Incoming WhatsApp order converts to Craftplan order draft with capacity/availability validation
- Catalog sync updates WhatsApp within sync cycle when products change
- Message templates render correctly with order-specific data (items, totals, pickup time)
- Failed messages surface in admin UI with retry options

### Implementation Notes

- Build generic channel adapter pattern that Shopify/Etsy can later implement
- Use pattern matching for message parsing (order intent, product queries, status requests)
- Consider storing conversation context in memory vs. DB (cost/speed tradeoff)
- Manual CSV import remains available as fallback for offline/no-integration scenarios

---

## Milestone 5 -- Insights & Pricing Intelligence

**Status:** [ ] Not started [ ] In progress [ ] Done

> ⚠️ **NEEDS FLESHING OUT** - Requires COGS calculation specs, dashboard wireframes, alert rule definitions, and report export formats

### Goals

- Deliver GAAP-aligned cost reporting, profitability dashboards, and pricing recommendations that leverage data from earlier milestones.

### User Stories

- As an owner, I see capacity utilization, margin by product, and sales trends in one dashboard.
- As a pricing analyst, I receive recommendations when costs drift or margins fall below thresholds.
- As an auditor, I export COGS reports with methodology notes.

### Requirements

**Data**

- [ ] New `Craftplan.Insights` context aggregating orders, batch costs, inventory adjustments.
- [ ] GAAP/IRS-compliant COGS calculations with configurable costing method (FIFO/rolling average).
- [ ] Alert engine for margin thresholds and over-capacity warnings.

**UI**

- [ ] `/manage/reports` LiveView with stat cards (capacity utilization, gross margin, top products/customers) and tables.
- [ ] Price drift alerts appearing on product overview tab; ability to accept suggested price.
- [ ] Export buttons (CSV/print) for each report section.

**Docs**

- [ ] Guides detailing costing assumptions and how to configure pricing rules.

### Acceptance Criteria

- COGS report reconciles with inventory movements and passes automated test suite with sample data.
- Pricing suggestions display inputs (unit cost, target margin) and allow quick apply to product.
- Dashboards perform within acceptable response times (<500ms typical dataset).

### Implementation Notes

- Preload data via `Ash.Query.load/2`; avoid N+1 queries.
- Add LiveView tests for KPI surfaces using fixtures.

---

## Milestone 6 -- Onboarding & Adoption

**Status:** [ ] Not started [ ] In progress [ ] Done

> ⚠️ **NEEDS FLESHING OUT** - Requires CSV template specs, demo scenario design, calculator wireframes, and onboarding checklist UX

### Goals

- Remove friction during setup with better CSV flows, demo assets, and calculators similar to competitor positioning.

### User Stories

- As a new tenant, I import products, materials, recipes, and customers with dry-run validation and contextual help.
- As a prospect, I explore a seeded bakery scenario, watch a short primer video, and print sample planner/labels.
- As a maker, I access calculators (pricing, production planning) from within the app.

### Requirements

**CSV & Importers**

- [ ] Wire product/material/customer importers to the wizard component; keep dry-run step.
- [ ] Add recipe importer supporting SKU lookups and BOM version assignment.
- [ ] Provide exporters for orders/customers/inventory movements.

**Demo & Content**

- [ ] Expand seeds to include multi-location bakery scenario and sample reports.
- [ ] Add quickstart guide (Markdown/LiveView) with embedded screenshots/video links.
- [ ] Surface calculators/templates (pricing, production planning) similar to Craftybase resources.

**UX Support**

- [ ] In-app checklist for onboarding tasks (mix of LiveView + persistent settings flags).

### Acceptance Criteria

- CSV wizard completes import with granular error reporting and generates summary results.
- Demo tenant can run through Operate -> Make -> Stock loop including costing and reporting surfaces.
- Onboarding checklist auto-updates as tasks completed and collapses once done.

---

## Backlog -- E-commerce Channel Sync

**Target:** Post-MVP (after M6 completion)

**Scope:** Shopify, Etsy, Square, Faire integrations for automated order import and inventory sync

**Rationale for deferring:**

- WhatsApp covers direct customer communication (higher priority for bakeries)
- CSV import handles bulk order scenarios
- Channel sync becomes more valuable once costing, forecasting, and insights are proven
- Can validate channel adapter pattern with WhatsApp first

**Future User Stories:**

- As a seller, I sync orders from Shopify/Etsy into Craftplan and keep inventory levels aligned
- As an operator, I receive marketplace orders alongside WhatsApp/manual orders in unified queue
- As a multi-channel seller, I see inventory automatically reserved across all channels

---

## Tracking & Delivery

- Keep `PLAN.md` milestone checkboxes in sync with progress; update "Last updated" date per change.
- Run `mix ash_postgres.generate_migrations` after domain changes and commit snapshots.
- Tests to add as features land:
  - BOM cost calculator edge cases (`test/craftplan/catalog`).
  - Traceability recall flow (`test/craftplan/traceability`).
  - Reorder suggestion algorithm (`test/craftplan/inventory`).
  - WhatsApp integration adapters (mock API clients).
  - Insights dashboard LiveView tests using fixtures.
- Documentation touchpoints: update README feature matrix + guides after each milestone.
- Competitive watch: review Craftybase roadmap quarterly and fold learnings into this plan.
