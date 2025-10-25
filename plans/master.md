Craftplan Product Plan -- Bakery ERP Roadmap

Last updated: 2025-10-19

Progress Snapshot
- Overall: [ ] Not started / [x] In progress / [ ] Done
- Current Cycle (Oct 2025): Stabilize internal print flows + prep costing foundations.
- Milestone Health
  - [ ] M0: Launch Readiness Backlog (Active)
  - [ ] M1: Production Costing Foundations
  - [ ] M2: Traceability & Compliance
  - [ ] M3: Inventory Planning & Purchasing
  - [ ] M4: Commerce & Channel Sync (Optional)
  - [ ] M5: Insights & Pricing Intelligence
  - [ ] M6: Onboarding & Adoption

Recently Completed
- Planner split into Overview/Schedule tabs; schedule calendar isolates day view.
- Over-capacity highlights in planner with metrics modal across tabs.
- Make Sheet print view hides navigation and actions; invoice printable HTML scaffolded.
- Product capacity (`max_daily_quantity`) enforced at checkout alongside global capacity.
- Public storefront retired in favor of a login-first screen; capacity/tax/fulfillment settings remain for internal planning.
- CSV import LiveComponent refactor with reusable wizard, per-entity configs, and LiveView tests.
- Orders and Inventory LiveViews aligned to settings-inspired layout primitives with shared components.

Competitive Insights -- Craftybase Highlights
- Multi-stage BOMs with components/sub-assemblies and labor costing; generates real-time cost rollups and pricing suggestions.
- Compliance and traceability tooling: lot/batch tracking, recall workflows, audit-friendly reports.
- Location-aware inventory with stock transfers, consignment tracking, and guided stocktake/cycle count tooling.
- Automated COGS calculations (GAAP/IRS aligned) feeding reports and profitability dashboards.
- Integrated channel sync (Shopify, Etsy, Square, Faire, Wix, WooCommerce, Amazon Handmade) with real-time stock updates.
- Templates and calculators (pricing, production planning) supporting onboarding and ongoing price optimization.

Guiding Principles
- Operate -> Make -> Stock remains the primary loop; extend with costing and compliance primitives rather than bespoke workflows.
- Self-host friendly and offline tolerant: webhooks/integrations should degrade gracefully to CSV or manual sync.
- Favor declarative Ash resources and LiveView streams; keep imperative logic in services only when needed.
- Every new surface must support printable artifacts (labels, planner, invoices, compliance reports).

--------------------------------------------------------------------
Milestone 0 -- Launch Readiness Backlog (1-2 weeks)
Status: [ ] Not started  [x] In progress  [ ] Done
Goals
- Close open polish items so production teams can demo a cohesive flow end-to-end.
- Lay groundwork for costing and traceability by shipping batch codes and label improvements.

User Stories
- As an admin, the login/landing screen highlights Craftplan’s value props and routes users to sign-in/reset flows.
- As a maker, I can print compliant product labels (ingredients/allergens/batch/date) with clean print styles.
- As an operator, make sheet and invoice prints respect `print:hidden` classes and no stray UI enters the printout.

Requirements
- Landing
  - [ ] Replace any remaining storefront routes with the login-focused public screen.
  - [ ] Ensure auth routes (`/sign-in`, `/reset`) remain reachable from the landing copy.
- Labels & Printing
  - [ ] Product label LiveView using existing invoice pattern; ensure batch/date placeholders.
  - [ ] Audit print classes across make sheet, invoice, and labels; add smoke tests.
- Cleanup
  - [ ] Remove unused helpers in `PlanLive` and confirm tab navigation highlights.

Acceptance Criteria
- Landing page loads without requiring session data and links into existing auth flows.
- Label printouts render without navigation and support 1-up & sheet layouts via CSS.
- Printed planner/invoice/label surfaces show only production data (no buttons/toolbars).

Implementation Notes
- Domain: ensure `OrderItem` optional `batch_code` exists for upcoming milestones.
- UI: login landing (`PageController`) plus `lib/craftplan_web/live/manage/product_label_live.ex`.
- Tests: Controller test for landing copy plus print toggles for labels/make sheet/invoice.

--------------------------------------------------------------------
Milestone 1 -- Production Costing Foundations (2-3 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Match competitor parity on multi-stage recipes, labor costing, and automated batch cost rollups.
- Provide pricing guidance hooks that later feed Insights.

User Stories
- As a product developer, I build a BOM with components, sub-assemblies, and labor entries.
- As an operator, completing a batch generates actual cost per unit and suggested price ranges.
- As a planner, I see batch codes auto-generated when marking production done.

Requirements
- Domain
  - [ ] New Ash resources for BOM structures: `Catalog.BOM`, `Catalog.BOMComponent`, `Catalog.LaborStep` with versioning.
  - [ ] Link BOM to `Catalog.Product`; support status (`draft`, `active`).
  - [ ] Labor rates and overhead settings in `Settings` (hourly rate, markup defaults).
  - [ ] Batch cost calculation service generating `material_cost`, `labor_cost`, `overhead_cost`, `unit_cost`.
  - [ ] Auto-generate `batch_code` (`B-YYYYMMDD-SKU-SEQ`) when order items marked done; persist to order items.
- UI
  - [ ] BOM editor LiveView with step builder, sub-assembly selector, labor entries.
  - [ ] Planner “Mark Done” dialog shows resulting batch code and actual cost snapshot.
  - [ ] Pricing helper card on product detail showing suggested retail/wholesale prices (based on markup settings).
- Data & Migrations
  - [ ] Tables for BOMs/components/labor; migrations keep existing products unaffected until BOM assigned.
  - [ ] Backfill seeds with example recipes (bread, pastry) including labor.

Acceptance Criteria
- Batch completion persists cost breakdown and batch code on order item; totals flow into invoices.
- Pricing helper toggles between markup types (percent/fixed) and respects inclusive/exclusive tax.
- BOM editor enforces valid graphs (no cycles) and supports saving draft vs publish.

Implementation Notes
- Consider `Ash.Flow` for multi-step BOM creation to reuse validations.
- Add unit tests for cost calculator (material shrinkage, multi-step components).
- Update documentation in guides for BOM/labor usage.

--------------------------------------------------------------------
Milestone 2 -- Traceability & Compliance (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Deliver lot tracking, recall readiness, and audit-friendly exports ahead of competitor parity claims.

User Stories
- As a quality lead, I can trace which batches used a recalled material and export affected orders.
- As an operator, I can record certifications/expiry on materials and be alerted during production.
- As a regulator, I can receive printable compliance reports showing batch lineage and disposition.

Requirements
- Domain
  - [ ] Extend inventory movements to capture `lot_number`, `expiry_date`, `certifications`.
  - [ ] Batch-to-material usage join resource for trace queries.
  - [ ] Recall log resource with status (`investigating`, `resolved`).
- UI
  - [ ] Traceability dashboard under `/manage/traceability` summarizing recent batches, open recalls, expiring materials.
  - [ ] Batch detail view linking orders, materials, and printable compliance sheet.
  - [ ] Warnings in planner when scheduled production will use expiring lots.
- Ops/Reports
  - [ ] Generate compliance export (CSV/HTML) for selected batch or date range.
  - [ ] Add audit trail events for lot assignments and recall resolutions.

Acceptance Criteria
- Given a recalled material lot, system lists all batches and orders containing it within seconds.
- Expiry warnings show within planner cards and block completion unless overridden with reason.
- Compliance exports include signature block and can be printed cleanly.

Implementation Notes
- Add composite indexes for lot/batch lookups.
- Build LiveView stream for traceability dashboard; include empty-state messaging.
- Tests: traceability query unit tests + LiveView flow for marking recall resolved.

--------------------------------------------------------------------
Milestone 3 -- Inventory Planning & Purchasing (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Move beyond low-stock alerts to actionable purchase workflows with location awareness.

User Stories
- As a purchasing manager, I review reorder suggestions by supplier and raise a PO in one click.
- As a stock controller, I transfer inventory between locations and consignments with audit history.
- As an owner, I perform rolling stocktakes that feed accuracy metrics without shutting down operations.

Requirements
- Inventory & Locations
  - [ ] Introduce `Inventory.Location` resource, transfer actions, and consignment tracking.
  - [ ] Location revenue/expense reporting aligned with orders.
  - [ ] Reorder engine considers lead time, safety stock, and upcoming production.
- UI
  - [ ] Inventory Overview tab: low-stock banner, forecast chart, reorder table grouped by supplier.
  - [ ] Purchasing LiveView: PO quick-create from suggestions, status tracker.
  - [ ] Stocktake workflow LiveView with guided counts (random/category/age-based selection) and variance report.
- Data & Integrations
  - [ ] Optional barcode import/export hooks for stocktakes (CSV upload now, future scanner integration).
  - [ ] Seeds include multi-location scenario (main bakery + farmer's market consignment).

Acceptance Criteria
- Reorder suggestions compute quantity with formula (forecast demand + safety stock - on hand - on order) and surface supplier.
- Stocktake completion generates variance adjustment entries and accuracy metrics.
- Purchasing flow updates inventory upon receiving and closes suggestion.

Implementation Notes
- Extend `InventoryForecasting` module; add tests covering location splits.
- Use LiveView streams for long reorder lists.
- Document stocktake best practices in guides.

--------------------------------------------------------------------
Milestone 4 -- Commerce & Channel Sync (Optional, 3 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Offer a lightweight integration path with major commerce channels while keeping self-host deployments viable.

User Stories
- As a seller, I sync orders from Shopify/Etsy into Craftplan and keep inventory levels aligned.
- As a bakery without integrations, I import daily orders via CSV template with the same validation flow.
- As an operator, I toggle Stripe checkout and redirect customers for payment when enabled.

Requirements
- Integrations
  - [ ] Provide integration adapters (start with Shopify + Etsy) using API keys stored encrypted.
  - [ ] Background job (Oban) to fetch orders/products and reconcile inventory.
  - [ ] Manual CSV import/export remains available as fallback.
- Storefront
  - [ ] Checkout LiveView optionally creates Stripe Checkout Session (using `stripity_stripe`).
  - [ ] Daily capacity and availability gating stays enforced across imported orders.
- Security & Config
  - [ ] Admin settings UI for API credentials, sync frequency, and dry-run preview.
  - [ ] Audit log for outbound API calls and failures.

Acceptance Criteria
- Inventory adjusts within one sync cycle after external order/import.
- Sync failures surface actionable errors and do not break manual order entry.
- Stripe-enabled checkout redirects correctly and records payment status.

Implementation Notes
- Start with read-only integrations (orders/products); write-backs can follow later.
- Provide mix task for manual sync trigger for self-host installs.

--------------------------------------------------------------------
Milestone 5 -- Insights & Pricing Intelligence (2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Deliver GAAP-aligned cost reporting, profitability dashboards, and pricing recommendations that leverage data from earlier milestones.

User Stories
- As an owner, I see capacity utilization, margin by product, and sales trends in one dashboard.
- As a pricing analyst, I receive recommendations when costs drift or margins fall below thresholds.
- As an auditor, I export COGS reports with methodology notes.

Requirements
- Data
  - [ ] New `Craftplan.Insights` context aggregating orders, batch costs, inventory adjustments.
  - [ ] GAAP/IRS-compliant COGS calculations with configurable costing method (FIFO/rolling average).
  - [ ] Alert engine for margin thresholds and over-capacity warnings.
- UI
  - [ ] `/manage/reports` LiveView with stat cards (capacity utilization, gross margin, top products/customers) and tables.
  - [ ] Price drift alerts appearing on product overview tab; ability to accept suggested price.
  - [ ] Export buttons (CSV/print) for each report section.
- Docs
  - [ ] Guides detailing costing assumptions and how to configure pricing rules.

Acceptance Criteria
- COGS report reconciles with inventory movements and passes automated test suite with sample data.
- Pricing suggestions display inputs (unit cost, target margin) and allow quick apply to product.
- Dashboards perform within acceptable response times (<500ms typical dataset).

Implementation Notes
- Preload data via `Ash.Query.load/2`; avoid N+1 queries.
- Add LiveView tests for KPI surfaces using fixtures.

--------------------------------------------------------------------
Milestone 6 -- Onboarding & Adoption (ongoing, 2 weeks)
Status: [ ] Not started  [ ] In progress  [ ] Done
Goals
- Remove friction during setup with better CSV flows, demo assets, and calculators similar to competitor positioning.

User Stories
- As a new tenant, I import products, materials, recipes, and customers with dry-run validation and contextual help.
- As a prospect, I explore a seeded bakery scenario, watch a short primer video, and print sample planner/labels.
- As a maker, I access calculators (pricing, production planning) from within the app.

Requirements
- CSV & Importers
  - [ ] Wire product/material/customer importers to the wizard component; keep dry-run step.
  - [ ] Add recipe importer supporting SKU lookups and BOM version assignment.
  - [ ] Provide exporters for orders/customers/inventory movements.
- Demo & Content
  - [ ] Expand seeds to include multi-location bakery scenario and sample reports.
  - [ ] Add quickstart guide (Markdown/LiveView) with embedded screenshots/video links.
  - [ ] Surface calculators/templates (pricing, production planning) similar to Craftybase resources.
- UX Support
  - [ ] In-app checklist for onboarding tasks (mix of LiveView + persistent settings flags).

Acceptance Criteria
- CSV wizard completes import with granular error reporting and generates summary results.
- Demo tenant can run through Operate -> Make -> Stock loop including costing and reporting surfaces.
- Onboarding checklist auto-updates as tasks completed and collapses once done.

--------------------------------------------------------------------
Tracking & Delivery
- Keep `PLAN.md` milestone checkboxes in sync with progress; update "Last updated" date per change.
- Run `mix ash_postgres.generate_migrations` after domain changes and commit snapshots.
- Tests to add as features land:
  - BOM cost calculator edge cases (`test/craftplan/catalog`).
  - Traceability recall flow (`test/craftplan/traceability`).
  - Reorder suggestion algorithm (`test/craftplan/inventory`).
  - Integration sync adapters (mock API clients).
  - Insights dashboard LiveView tests using fixtures.
- Documentation touchpoints: update README feature matrix + guides after each milestone.
- Competitive watch: review Craftybase roadmap quarterly and fold learnings into this plan.
