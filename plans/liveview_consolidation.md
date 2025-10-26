## Task 1 — Navigation & Breadcrumb Services
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

## Task 2 — Helper Function Rationalization
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
