# Inventory Forecast Grid Improvement Plan

Owner: You  
Drafted by: Coding agent (Codex)  
Last updated: 2025-10-19  
Status: Pending approval

## 1. Mission & Scope

- **Goal**: Deliver an owner-centric inventory forecast grid that answers “Am I safe?”, “When will I stock out?”, “When must I order?”, and “How much should I order?” in a single glance, aligned with micro-manufacturer heuristics (ROP, safety stock, cover, lead time).
- **Success**: A row exposes risk state, stockout date, order-by date, and suggested purchase quantity; service level & horizon adjustments update instantly; two-click PO creation from the grid; math is explained in plain language.
- **In scope**:
  - Computing and surfacing the owner metrics band (On hand, On order, Avg/day, LT, Safety, ROP, Cover, Stockout, Order by, Suggested PO).
  - Interactive controls for service level, planning horizon, risk filters, and what-if toggles.
  - Reusing daily requirement/balance chips to maintain explainability.
  - Create-PO shortcut prefilled from Suggested PO.
  - Right-rail help content and accessible status indicators.
- **Out of scope (phase 1)**:
  - Historical analytics beyond the active horizon.
  - Supplier-specific lead times/pack sizes if data is absent (support defaults, collect requirements for follow-up).
  - Automated PO dispatch; we focus on draft creation inside Craftplan.

## 2. Assumptions & Dependencies

- `Inventory.Forecast` (or equivalent domain layer) already returns per-day requirement and projected balance; we will extend it to compute per-material aggregates.
- Service level options (90/95/97.5/99) map to standard Z factors (1.28/1.65/1.96/2.33).
- Lead time is stored per material or supplier; if missing, use global default from Settings.
- Pack size (rounding basis) is available or defaults to 1.
- Forecast grid is a Phoenix LiveView under `CraftplanWeb.Manage.Inventory` (confirm actual module).
- Target performance: recompute up to 500 materials × 28 days without noticeable lag (<200 ms server processing).
- Accessibility requires textual labels alongside color chips.

## 3. Workstreams & Milestones

### Milestone A — Foundations (Domain & Data) *(~3 days)*

- [ ] Audit existing inventory forecast data flow and document current structs/queries.
- [ ] Introduce or extend calculations for:
  - [ ] Average daily use (`avg_daily_use`) per horizon, with fallback to recent history.
  - [ ] Demand variability (`stddev_daily_use`) or proxy (0.5 × average) when history is insufficient.
  - [ ] Demand during lead time (`avg_daily_use * lead_time_days`).
  - [ ] Safety stock (`Z * stddev_daily_use * sqrt(lead_time_days)`).
  - [ ] Reorder point (`lead_time_demand + safety_stock`).
  - [ ] Days of cover (`on_hand / avg_daily_use`, guard against zero).
  - [ ] Stockout date (first projected balance < 0 within horizon, else `nil` / “beyond horizon”).
  - [ ] Order-by date (`stockout_date - lead_time_days`, guard against nil).
  - [ ] Suggested PO quantity (`max(0, reorder_point - (on_hand + on_order_qty))`, rounded to pack size).
- [ ] Capture supporting fields (`on_hand`, `on_order_qty`, `lead_time_days`, `pack_size`, `perishable_cap_days?`).
- [ ] Update Ash resources/actions to surface these fields in forecast reads; ensure snapshots & migrations stay aligned if schema changes are needed.
- [ ] Add unit tests (Ash data layer) for calculation accuracy with representative scenarios, including provided acceptance scenario.

### Milestone B — LiveView & UI Architecture *(~3 days)*

- [ ] Design owner metrics band layout:
  - [ ] Fixed columns (Material → ROP) before horizontal scroll.
  - [ ] Cover chip with color states (red/amber/green) and accessible labels.
  - [ ] Stockout/order-by display (dates or “—” / “beyond horizon” fallbacks).
  - [ ] Suggested PO cell with action affordance.
- [ ] Add controls bar:
  - [ ] Service level selector (segmented toggle or dropdown).
  - [ ] Horizon selector (7/14/28 days).
  - [ ] Risk filter chips (Shortage/Watch/Balanced).
  - [ ] What-if toggles (demand ±10%, lead time override) with UX spec.
- [ ] Implement LiveView assigns updates to recompute metrics when controls change (coordinate with backend query parameters).
- [ ] Ensure daily cells (existing chips) remain and align visually with new columns.
- [ ] Instrument right-rail help panel with glossary/tooltips; add `phx-click` or hover triggers as appropriate.

### Milestone C — Interactions & Actions *(~2 days)*

- [ ] Implement Suggested PO → “Create PO” flow:
  - [ ] Prefill PO draft (SKU, supplier, quantity, target receipt date) and navigate to Purchasing.
  - [ ] Honor perishable cap if present (truncate to max cover days).
  - [ ] Handle zero or null Suggested PO gracefully (disable action, show tooltip).
- [ ] Propagate risk states:
  - [ ] Shortage when any projected balance < 0.
  - [ ] Watch when balance hits 0 or equals requirement.
  - [ ] Balanced otherwise.
  - [ ] Sync with existing legend/banner colors.
- [ ] Add filter logic & LiveView instrumentation for risk chips and what-if toggles.
- [ ] Provide test coverage for LiveView events (`render_change`, `render_click`) to validate recomputation and PO creation path.

### Milestone D — Non-Functional, QA & Launch *(~2 days)*

- [ ] Performance profiling with sample dataset (500 SKUs, 28-day horizon); optimize queries/preloads.
- [ ] Accessibility audit: contrast, aria-labels, keyboard focus, assistive text for color cues.
- [ ] Content review: plain-language copy for right rail, tooltips, state labels.
- [ ] Update documentation (`guides/`, help copy) and internal enablement notes.
- [ ] Run full test suite; add targeted regression tests for calculations and LiveView; ensure `mix format`/dialyzer pass (if in use).
- [ ] Capture release notes and update `PLAN.md` milestones checklist (M2 Inventory & Purchasing).

## 4. Detailed Task Breakdown

### 4.1 Data & Calculations

- Define a central calculator module (e.g., `Craftplan.Inventory.ForecastMetrics`) with pure functions and unit tests.
- Extend Ash Read action (`ForecastGrid.read_owner_metrics?`) to load new fields and computed metrics.
- Ensure `Ash.Query.load/2` covers nested calculations to avoid N+1 database calls.
- Handle edge cases:
  - Avg/day = 0 → Cover shows “—”, Balanced unless explicit horizon requirement.
  - Lead time > horizon → report stockout “beyond horizon” but compute order-by date.
  - Missing on-order data → treat as zero.
  - Perishable cap → apply min between suggested quantity-derived cover and cap.

### 4.2 LiveView Implementation

- Update `lib/craftplan_web/live/manage/inventory/forecast_live.ex` (confirm exact file) to:
  - Initialize new assigns (`service_level`, `horizon_days`, `risk_filters`, `demand_delta`, `lead_time_override`).
  - Use `to_form` for any inline editing (e.g., manual overrides).
  - Stream daily cells if not already streaming; ensure metrics band uses assigns.
- Adjust HEEx template:
  - Add metrics band columns with `<.table>` or existing table components.
  - Embed Cover chip using class list conditional colors.
  - Provide explicit IDs for testing (`#material-<id>-create-po`).
  - Right rail content within `<aside>` or existing layout slot.
- Include tooltip content via shared components (`CraftplanWeb.Components.Tooltip`).

### 4.3 UX Content & Copy

- Draft tooltip strings using provided Appendix A explanations.
- Add glossary in right rail with details referencing service levels and ROP formula.
- Ensure consistent terminology across grid, tooltips, and help panel.

### 4.4 Testing Strategy

- **Unit**: Calculator module for metrics; rounding behavior; perishable cap logic.
- **Integration**: Ash read/action tests verifying dataset returned to LiveView.
- **LiveView**:
  - Service level change triggers metric recalculations and color updates.
  - Risk filter toggles display expected rows.
  - Create PO action routes with prefilled params.
- **Visual/Manual**:
  - Confirm performance on seeded data.
  - Accessibility tooling (axe DevTools or mix task if available).

## 5. Deliverables

- Updated domain modules and migrations (if needed).
- Enhanced LiveView with owner-centric grid, controls, and right rail.
- PO creation hook into Purchasing.
- Documentation updates (guide, tooltips, release notes).
- Automated tests covering new logic and flows.

## 6. Risks & Mitigations

- **Data gaps (lead time, pack size)**: Provide sensible defaults, surface warnings in right rail, capture follow-up tasks.
- **Performance regressions**: Memoize repeated calculations and preload orders; consider caching aggregated metrics per horizon/service level.
- **User confusion with what-if toggles**: Add inline indicators showing active adjustments; allow reset to defaults.
- **Edge cases (perishables, zero demand)**: Explicit conditions with UX feedback to prevent misleading suggestions.

## 7. Open Questions (Need Product/Design Input)

1. Should `avg_daily_use` derive from horizon plan or historical consumption when both are available?
2. Do we have per-supplier lead times & pack sizes now, or should UI collect them in follow-up work?
3. Which materials require maximum-cover caps because of perishability?
4. Should Suggested PO respect supplier minimum order quantities if present?
5. Do we display stockout/order-by dates in absolute (MM/DD) or relative (“in 5 days”) format?

## 8. Approval Checklist

- [ ] Product owner signs off on scope and milestones.
- [ ] Design confirms layout, color rules, and glossary content.
- [ ] Engineering agrees on feasibility and sequencing.
- [ ] Data availability confirmed for lead time, pack size, demand history.
