# LiveView & Component Consolidation — Task Tracker

Each task below is self-contained and marked with a checkbox for tracking. Update the checkbox when the task is completed and keep notes (blocked, in review, etc.) under the **Status Log** subsection.

---

## Task 1 — Generic Form Behaviour
- [ ] **Status:** _Not started_

### Context
Nearly every LiveComponent form (products, suppliers, materials, purchase orders, customers, etc.) reimplements the same `assign_form`, `validate`, and `save` logic. This creates copy/paste bugs and inconsistent flash messaging.

### Deliverables
1. Introduce `CraftplanWeb.FormComponent` (macro or behaviour) encapsulating shared patterns:
   - `c:form_config/1` callback describing resource, action, and nested forms.
   - Default `update/2` that loads records, runs `Form.for_create/for_update`, and assigns `@form`.
   - Shared `handle_event("validate")` and `handle_event("save")`, including flash, `push_patch`, and parent notifications.
2. Provide override hooks (`handle_save_result/2`, `after_validate/2`) so specialized components (e.g., Order items consumption) can extend behaviour.
3. Migrate representative components:
   - Simple CRUD (SupplierFormComponent).
   - Nested form (Customer form with billing/shipping).
   - Complex one (Product form or Settings form) to prove extensibility.
4. Update developer docs (`guides/ui_helpers.md` or CONTRIBUTING) explaining how to opt in.
5. Add component/unit tests covering the macro (success path, error path, override hooks) and update existing LiveComponent tests to assert behaviour via the shared helpers.

### Status Log
- _Add notes here (e.g., “In progress – Alice 2024‑05‑10”)._


---

## Task 2 — List Editor Component
- [ ] **Status:** _Not started_

### Context
Order line items, recipe components, nutritional facts, and allergen assignments all render near-identical table layouts with `<.inputs_for>`, manual headers, `Form.add_form/2`, `Form.remove_form/2`, and availability calculations.

### Deliverables
1. Create `CraftplanWeb.Components.ListEditor`:
   - Accepts `form`, `field`, `columns` metadata (label, width, slot), action slot(s), and optional “add-row” configuration.
   - Provides helper functions `ListEditor.add_entry/3`, `ListEditor.remove_entry/2`, and `ListEditor.selected_ids/1`.
   - Emits standardized events (`"list_editor:add"`, `"list_editor:remove"`) and handles hidden inputs when needed.
2. Supply availability helpers for “choose from remaining” scenarios (products/materials/facts).
3. Replace custom implementations in:
   - `OrderLive.FormComponent` (items list).
   - `ProductLive.FormComponentRecipe` (materials).
4. Document usage with HEEx snippets and instructions on customizing row cells.
5. Add component tests for ListEditor (header rendering, row add/remove events, availability filtering) and update refactored LiveComponent tests accordingly.

### Status Log
- _


---

## Task 3 — Calendar & Filter Toolkit
- [ ] **Status:** _Not started_

### Context
Order, Inventory, and Plan LiveViews all implement their own filter parsing, `calculate_days_range`, `generate_week_range`, and navigation events (`prev_week`, `next_week`, `today`) plus similar header UI.

### Deliverables
1. Build `CraftplanWeb.Live.FilterParams`:
   - Declarative definition of filter fields (type, multi-select, default).
   - Functions to parse `%{"filters" => params}` into typed maps.
2. Build `CraftplanWeb.Live.CalendarNavigation`:
   - Helpers returning `{days_range, current_week_start}` and JS-safe event names.
   - Reusable component for the period toggle bar (prev/today/next).
3. Refactor `OrderLive.Index`, `InventoryLive.Index`, and `PlanLive.Index` to use the toolkit, removing local helpers.
4. Ensure heavy UI pieces (week header, empty states) move into composable `Page.surface` helpers to stay consistent.
5. Add test coverage (unit tests for FilterParams, LiveView tests for navigation events) to guarantee consistent behaviour across screens.

### Status Log
- _


---

## Task 4 — Tabbed Show Scaffolding
- [ ] **Status:** _Not started_

### Context
Order/Product/Inventory/Purchasing/Customer “Show” pages all rebuild tab arrays, breadcrumbs, and modals manually, leading to inconsistent tabs and repeated code.

### Deliverables
1. Introduce `CraftplanWeb.Components.TabbedShow`:
   - Props for header title, tab list (`label`, `navigate`, `visible?`, `actions`), and breadcrumbs.
   - Slots for each tab’s content and for header action buttons.
   - Built-in support for associated modals (edit dialogs, nested forms).
2. Provide helper functions for constructing tab definitions from standard resource metadata.
3. Refactor the five major Show views to consume the component.
4. Add component tests verifying tab switching, active styling, breadcrumb display, and modal wiring; update LiveView tests to use the shared helper.

### Status Log
- _


---

## Task 5 — Taxonomy Managers (Allergens & Nutritional Facts)
- [ ] **Status:** _Not started_

### Context
`SettingsLive.AllergensComponent`, `SettingsLive.NutritionalFactsComponent`, and inventory forms share the same search/filter modal logic, multi-select state, and Ash mutations.

### Deliverables
1. Create `CraftplanWeb.Components.TaxonomyManager` with configurable labels, loader, creator, and deleter functions.
2. Support search filtering, modal add flow, deletion, and toast feedback.
3. Localize differences (copy, column titles) via assigns rather than copy/paste modules.
4. Update material-level assignment components (allergens + nutritional facts) to reuse shared pickers/state helpers.
5. Write LiveComponent tests for create/delete/filter flows (both settings-level and material-level usages).

### Status Log
- _


---

## Task 6 — Photo Upload Gallery
- [ ] **Status:** _Not started_

### Context
`ProductLive.FormComponentPhotos` handles uploads, warnings, progress, removal, and featured photo toggling manually. Future asset managers would have to repeat the work.

### Deliverables
1. Build `CraftplanWeb.Components.PhotoGallery`:
   - Props: `uploads`, `photos`, `featured`, validation limits.
   - Emits events for cancel, remove, set-featured, and exposes `gallery_changed?/1`.
2. Provide hooks for host components to plug into the generic form behaviour (Task 1).
3. Migrate current photo component to the gallery, ensuring all behaviours (warnings, change disable, featured indicator) remain intact.
4. Write documentation and tests covering drag/drop, in-progress previews, and change state.

### Status Log
- _


---

## Task 7 — Navigation & Breadcrumb Services
- [ ] **Status:** _Not started_

### Context
Every LiveView builds its own `nav_sub_links` array and breadcrumb list. Some lists diverge or contain bugs (forgetting `current?`). We want a declarative model consumed by the layout.

### Deliverables
1. Define a navigation registry (`CraftplanWeb.Navigation`) describing each section’s root label, path, and sub-links.
2. Implement `Navigation.assign/3` or similar helper:
   - Accepts `socket`, `section`, and a declarative trail (e.g., `[{orders: :root}, {:order, order}]`).
   - Assigns both `:nav_sub_links` (with active detection) and `:breadcrumbs`.
3. Update `use CraftplanWeb, :live_view` to alias/import the helper so every LiveView calls it from `handle_params/3`.
4. Migrate LiveViews section by section:
   - Orders → Inventory → Purchasing → Customers → Settings → Plan.
   - Remove any manual breadcrumb lists.
5. Add regression tests ensuring breadcrumb structure is consistent (list of maps with `label`, `path`, `current?`) and nav active states match the requested section.

### Status Log
- _


---

## Task 8 — Helper Function Rationalization
- [ ] **Status:** _Not started_

### Context
Private helpers like `format_day_name/1`, `format_short_date/2`, `generate_week_range/2`, and `is_today?/1` are redefined in multiple modules despite `CraftplanWeb.HtmlHelpers` already covering similar ground.

### Deliverables
1. Inventory formatting/date helpers across the LiveViews.
2. Extend `CraftplanWeb.HtmlHelpers` (or create `DateHelpers`) with the missing shared helpers, ensuring they handle both `Date` and `DateTime` inputs and accept timezone/format options.
3. Update `CraftplanWeb` macro to import the consolidated helper library for LiveViews and components.
4. Remove duplicated private helpers from LiveViews, replacing them with shared calls. Run formatter + tests to ensure no references remain.
5. Document the helper catalogue (purpose, arguments, examples) in `guides/ui_helpers.md`.
6. Add unit tests for the new helper functions and update any LiveView tests depending on their behaviour (e.g., date formatting assertions).

### Status Log
- _

---

## Task 9 — Execution & Risk Management
- [ ] **Status:** _Not started_

### Context
The refactor spans multiple teams/files. We need coordination, documentation, and test coverage.

### Deliverables
1. Define sequencing (e.g., Task 1 and 7 first, then others) in `PLAN.md`.
2. Ensure each task/PR includes component tests or LiveView tests to maintain coverage.
3. Track progress in this file, updating checkboxes and notes.
4. Provide roll-out guidance (feature flags if needed) and communicate changes to the team (e.g., weekly update in Slack/PLAN.md).
5. Ensure every PR tied to these tasks includes appropriate tests (unit, component, or LiveView) and note test coverage in the Status Log.

### Status Log
- _

---

**Reminder:** Keep this file updated as tasks progress. When adding new subtasks or clarifications, include them under the relevant task’s Status Log section. !*** End Patch to=functions.apply_patch זיך code```json to=functions.apply_patch
