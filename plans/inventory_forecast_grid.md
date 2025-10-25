# Inventory Forecast Grid Improvement Plan

Owner: You
Drafted by: Coding agent (Codex)
Last updated: 2025-10-25
Status: Milestone B kickoff – LiveView defaults + component skeletons queued

---

## 1. Mission, Scope & Success Criteria

- **Mission**: Deliver an owner-facing forecast grid that makes “am I safe?”, “when do I stock out?”, “when must I order?”, and “how much should I order?” obvious without leaving the page.
- **Primary outcomes**:
  - Every material row exposes current risk tier, projected stockout date, order-by date, and a Suggested PO quantity anchored in ROP math.
  - Service level, horizon, and what-if controls rehydrate the grid in <200 ms with responsive status chips and explanations.
  - A two-click CTA launches a prefilled PO draft while preserving forecast context for easy back-and-forth.
  - Embedded glossary/right-rail copy explains the formulas in plain language and passes accessibility checks.
- **Scope (Phase 1)**:
  - Compute and display the owner metrics band (On hand, On order, Average daily use, Demand variability, Lead time demand, Safety stock, ROP, Cover, Stockout, Order-by, Suggested PO, Risk state).
  - Interactive controls for service level (90/95/97.5/99), horizon (7/14/28 days), risk filters, demand delta (+/-10%), and optional lead-time override.
  - Reuse the existing day-by-day requirement/balance chips for continuity; add crosslinks into Purchasing for PO creation.
  - Right-rail containing glossary, formula callouts, and an activity log of recent PO submissions.
- **Explicit exclusions**:
  - Automated PO transmission (email/EDI) and supplier confirmations.
  - Supplier-level overrides where data does not exist yet (collect follow-up requirements instead).
  - Historical analytics beyond the selected planning horizon.

---

## 2. Approach Overview

1. **Data-first**: Extend the domain layer (`Craftplan.Inventory.Forecast`) with pure, well-tested metric functions and Ash actions that return rich aggregates in a single trip. Keep LiveView lean by consuming these computed values directly.
2. **Composable UI**: Introduce a metrics band component that can be embedded elsewhere (e.g., supplier detail pages) and stream updated rows for fast recomputation. Use LiveView streams for day chips and assign-based refresh for metrics to keep diff payloads tight.
3. **Explainability**: Pair every numeric state with copy (tooltip, glossary, or inline label) so operators understand why a suggested quantity changed. Favor existing design tokens for color/risk semantics and ensure ARIA labelling.
4. **Operational hooks**: Route Suggested PO actions into Purchasing with a parameterised Ash Flow that prebuilds drafts, making it trivial to extend to automation later.
5. **Iterative validation**: Build the calculator and LiveView behind feature flags; drive acceptance with fixture-backed tests and sample bakery data seeded via `mix ash.setup`.

---

## 3. Assumptions, Dependencies & Inputs

- `Inventory.Forecast` already produces daily requirements and projected balances; we will extend it to compute per-material aggregates without duplicating SQL.
- Lead time is stored per material (preferred) or per supplier; a global fallback exists in Settings. Missing values default to `settings.default_lead_time_days`.
- Pack size (rounding basis) and optional perishable-cap days are defined; if absent, assume `1` and `nil`.
- Average daily use follows an industry baseline: blend the trailing 6 weeks of actual consumption (60 %) with the next 2 weeks of planned demand (40 %); fall back to trailing actuals when plans are missing, and smooth variability with the same sample.
- Demand variability uses the blended sample’s standard deviation; if fewer than 10 data points exist, apply 0.5 × average as a conservative proxy.
- Forecast LiveView resides under `CraftplanWeb.Manage.Inventory.ForecastLive` (verify actual path). The LiveView already loads day chips; we will enrich assigns and templates.
- Purchasing already exposes an action or LiveView that can accept `material_id`, `supplier_id`, `quantity`, `target_receipt_date` parameters for draft creation.
- Performance target: <=200 ms server processing for 500 materials × 28-day horizon; client diff under 50 KB.
- Accessibility baseline: Tailwind tokens available; accessible status chips require ARIA labels describing risk and next action.
- Supplier-specific overrides are not required for Phase 1; rely on material-level defaults and the global fallback for gaps.

---

## 4. Workstreams, Milestones & Exit Criteria

> Estimated timeline assumes one engineer + one designer pairing lightly. Adjust as staffing changes.

### Milestone A — Domain Foundations (3–4 dev days)

**Objectives**: Comprehensive metrics calculator, Ash actions exposing data, regression tests.

- [x] Inventory the existing forecast pipeline: data sources, Ash resources, and LiveView assigns; capture architectural notes in `docs/architecture/inventory_forecast.md`.
- [x] Introduce `Craftplan.Inventory.ForecastMetrics` with pure functions:
  - `avg_daily_use/2`, `demand_variability/2`, `lead_time_demand/2`, `safety_stock/2`, `reorder_point/2`, `cover_days/2`, `stockout_date/2`, `order_by_date/2`, `suggested_po_qty/2`, `risk_state/2`.
  - Cover guards: zero demand, missing lead time, perishable caps (respect optional `max_cover_days` field).
- [x] Extend or create Ash read action (`:owner_grid_metrics`) to hydrate new fields. Ensure it uses a single query with `Ash.Query.load/2` for day-level data.
  - ✅ `Craftplan.Inventory.ForecastRow` embedded resource + manual `:owner_grid_metrics` action now returns metrics-ready rows from live material + demand joins with no N+1 queries.
  - 🧪 Action regression covered via fixture-backed loads; LiveView consumers can now rely on a single payload for metrics + day chips.
- [x] Update Ash resource snapshots + generate new migrations if new persisted fields are introduced.
  - ✅ Snapshots regenerated after wiring `ForecastRow` (no DB schema deltas required).
- [x] Add calculator unit tests covering: steady demand, zero demand, spike demand, long lead time, perishable cap, existing PO offset.
- [x] Acceptance: `mix test test/craftplan/inventory/forecast_metrics_test.exs` passes with new cases (`ForecastRow` integration test added).

### Milestone B — LiveView & Interaction Architecture (3 dev days)

**Objectives**: Responsive metrics band, control panel, and diff-friendly updates.

- [x] Confirm LiveView module path; refactor mount/init to assign defaults: `service_level`, `horizon_days`, `risk_filters`, `demand_delta`, `lead_time_override`, `metrics_loaded?`.
  - ✅ Owner metrics moved into dedicated `CraftplanWeb.InventoryLive.ReorderPlanner` (`/manage/inventory/forecast/reorder`) with planning controls, service-level/horizon toggles, and `InventoryComponents.metrics_band/1` wiring.
  - ⚠️ Session persistence + telemetry spans still pending; defaults reset on refresh until we add a storage hook.
- [~] Introduce a metrics band component under `CraftplanWeb.Components.Inventory` with:
  - Fixed columns: Material, On hand, On order, Avg/day, Demand variability, Lead-time demand, Safety stock, ROP.
  - Computed columns: Cover chip (color-coded), Stockout date, Order-by date, Suggested PO with CTA button.
  - Inline explainers using `<.tooltip>` / `<.icon_help>` patterns.
  - ✅ `CraftplanWeb.Components.Inventory.metrics_band/1` now renders risk chips, numeric columns, empty/loading states, and stub CTA buttons injected into the LiveView (`#owner-metrics-band`).
  - Component API: `metrics_band(assigns)` expects `rows`, `service_level`, and `horizon_days`; emits `phx-value-material-id` on CTAs and wraps risk chips via `risk_chip_classes/1`.
  - 📅 Design review w/ Jules & Priya on 2025-10-27 to lock spacing, chip colors, glossary entrypoints, and button hierarchy.
- [~] Implement control bar with accessible toggles (radio-group for service level, segmented control for horizon, pill chips for risk filters, what-if toggles).
  - Use `<.button_group>` patterns from shared components; ensure each control exposes `aria-describedby` tooltips describing impact on Suggested PO.
  - Persist “what-if” adjustments in the LiveView socket and surface a `Reset to actuals` button tied to a `phx-click="reset_adjustments"`.
  - ✅ Service level + horizon toggles live in the Reorder Planner page; risk filters/what-if toggles still pending.
- [ ] Wire LiveView `handle_event/3` callbacks to trigger Ash reads with updated params and reassign metrics; maintain streaming for day chips.
  - Events to cover: `"set_service_level"`, `"set_horizon"`, `"toggle_risk_filter"`, `"adjust_demand"`, `"override_lead_time"`.
  - Use `debounce` for sliders/toggles when appropriate and preserve `stream(:forecast_rows, ...)` for the day chips.
- [ ] Add right-rail `<aside>` with glossary cards (including “How we calculate Suggested PO”), last PO activity (if available), and surfaced warnings when defaults or caps are applied.
  - Right rail pulls copy from a glossary data module to avoid inline prose; include activity list component that links back to Purchasing drafts.
- [ ] Acceptance: LiveView tests confirm `<#forecast-grid>` updates risk state and suggested PO after changing controls; HTML diff limited to impacted rows.
  - Add/extend `test/craftplan_web/live/manage/inventory/forecast_live_test.exs` with scenarios covering default mount, service-level change, risk filter application, and glossary visibility toggles.

### Milestone C — PO Flow & Advanced Interactions (2 dev days)

**Objectives**: Actionable Suggested PO, risk filtration, what-if overlays.

- [ ] Create `Craftplan.Inventory.Forecast.PurchaseOrderFlow` (or reuse existing) that:
  - Receives metrics payload, calculates recommended receipt date (`stockout_date - 1` or `order_by` + lead time), and rounds to pack size.
  - Applies optional `max_cover_days` by capping Suggested PO to the cover limit before rounding.
  - Invokes Purchasing domain (`Purchasing.PurchaseOrder` create draft action) with necessary data.
- [ ] LiveView integration:
  - CTA button emits `phx-click="create_po"` event; handle to start flow and push navigate to Purchasing with flash indicating context.
  - Disable CTA + show tooltip when suggested quantity <= 0 or risk state Balanced.
- [ ] Implement risk filter logic (Shortage, Watch, Balanced) and what-if adjustments (demand delta, lead-time override) with visual indicators when toggles deviate from defaults.
- [ ] Acceptance: LiveView tests for `render_click(view, "#material-123-create-po")` verifying navigation; risk filter hides rows as expected.

### Milestone D — Performance, Accessibility & Launch Readiness (2 dev days)

**Objectives**: Quality gates, docs, release prep.

- [ ] Load-test with fixture dataset (500 materials × 28 days) using `mix run priv/perf/forecast_grid_seed.exs`; profile Ash query time and LiveView diff size.
- [ ] Address hotspots (preloading, memoization, or ETS caching for repeated metrics).
- [ ] Accessibility sweep: add aria-labels to cover chips, ensure color contrast, confirm tab order; use automated tooling (`axe-core` via browser or LiveView test helper if available).
- [ ] Audit logging: capture what-if adjustments and PO draft creations with before/after key metrics via `AuditLog` resource (or equivalent) for compliance.
- [ ] Documentation: update glossary, right-rail copy, `guides/operations/inventory_forecast.md`, release notes, and `PLAN.md` milestone checkbox.
- [ ] Test suite: `mix format`, `mix test`, dialyzer (if enabled); ensure new tests for calculators, Ash actions, and LiveView pass.
- [ ] Acceptance: Stakeholder review completed; readiness checklist signed off.

---

## 5. Technical Breakdown & Owners

- **Calculator & Actions** *(Backend engineer)*:
  - Define metric functions with documented formulas and guard clauses.
  - Extend Ash resources (`Inventory.Material`, `Inventory.ForecastEntry`) as needed.
  - Ensure `Ash.load/3` invocations include the metrics aggregator to prevent N+1 queries.
- **LiveView & Components** *(Full-stack engineer)*:
  - Build metrics band and controls as reusable components.
  - Maintain `to_form` patterns for any inline user input.
  - Use LiveView streams for row updates; maintain deterministic DOM IDs for testing.
- **Design & UX** *(Designer + Front-end)*:
  - Validate layout across desktop/tablet breakpoints; supply Tailwind class tokens.
  - Author glossary/tooltips copy; align colors with risk legend.
- **Purchasing Flow Integration** *(Backend/Full-stack)*:
  - Confirm upstream Purchasing APIs; handle draft navigation and error states.
  - Log PO draft creation events for audit (`AuditLog` resource if available).
- **QA & Enablement** *(QA engineer/PM)*:
  - Define acceptance scenarios per risk tier.
  - Coordinate customer pilot walkthrough; capture feedback loops.

---

## 6. Data Validation & Observability

- Seed scenario-based fixtures under `test/support/fixtures/inventory_forecast_fixture.ex`.
- Add telemetry events (`[:craftplan, :inventory, :forecast, :refresh]`) capturing duration, row count, horizon, and service level.
- Instrument PO creation path with success/failure counts and emit audit events when what-if adjustments precede a PO creation.
- Ensure metrics calculations log warnings when defaults kick in (e.g., missing lead time) and surface them in the right rail as non-blocking alerts.

---

## 7. Risks & Mitigations

- **Incomplete master data (lead times, pack sizes)** → Provide defaults, track missing data warnings, and raise follow-up tasks for data enrichment.
- **Performance regression with large horizons** → Pre-aggregate demand metrics per material/horizon and cache for the duration of the session; fall back to background recomputation if >200 ms.
- **Misinterpretation of Suggested PO** → Pair CTA with inline explanation and “View math” link to glossary. Add copy that clarifies service level impact.
- **What-if toggles causing user confusion** → Keep sticky banner summarising active adjustments with “Reset to actuals” button.
- **Accessibility gaps** → Schedule explicit axe scan + keyboard walkthrough before release; keep a11y notes in QA checklist.

---

## 8. Decisions & Remaining Questions

- Average daily use & variability use the blended actual/plan approach described above.
- Supplier-specific overrides can be deferred; rely on material-level data plus defaults.
- Suggested PO enforces optional `max_cover_days` to guard perishables (defaults to no cap).
- Supplier MOQs are out of scope for Phase 1.
- Stockout and order-by dates render as absolute `MM/DD` values (app locale).
- Audit logs are required whenever what-if adjustments feed into PO creation.
- `Craftplan.Inventory.ForecastRow.owner_grid_metrics` serves as the interface between domain data and LiveView, ensuring all calculations reuse `ForecastMetrics`.

Outstanding questions: None for Phase 1. Revisit as new requirements emerge.

---

## 9. Immediate Next Steps

1. Add telemetry + instrumentation for `CraftplanWeb.InventoryLive.ReorderPlanner` metrics loads (duration, row count, service level, horizon) and persist planner defaults to session/user settings.
2. Partner with design to finalize the Reorder Planner control bar (risk filters, demand delta, lead-time override) and wire events into the LiveView.
3. Implement what-if controls + risk filtering so the metrics band re-hydrates rows according to the toggles.
4. Build the glossary/right-rail component and surface warnings when defaults (lead time, pack size) kick in.
5. Hook the Suggested PO CTA into Purchasing (flow + navigation) and extend LiveView tests for CTA disabled states and risk filtering.
