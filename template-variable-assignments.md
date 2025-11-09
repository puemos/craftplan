# Template Variable Assignments

Searches for `<%` statements that define local variables (`<% var = ... %>` or multi-line `<% var = ...`) were conducted with both the greedy regex (`rg --pcre2 -n -U "<%(?![=])[^%]*=[^%]*%>"`) and the line-level scan (`rg -n "<%\\s*[^=][^%]*="`). Only the render blocks listed below matched those filters inside `lib/craftplan_web`.

## Findings in `lib/craftplan_web`

- `lib/craftplan_web/components/core.ex:382-385` – `<% current_idx = Enum.find_index(...) ... %>` keeps the stepper’s current step index available for later comparisons inside the `stepper` component; because the lookup spans multiple lines, the assignment is anchored at line 382 but runs through 385.
- `lib/craftplan_web/components/core.ex:387` – `<% current? = String.downcase(...) == String.downcase(to_string(step)) %>` flags whether the looped `step` matches the current value when rendering each step.
- `lib/craftplan_web/components/layouts.ex:222` – `<% primary_links = if @is_manage?, do: @manage_links, else: @shop_links %>` chooses which navigation links to iterate in the sidebar depending on the `@is_manage?` flag.
- `lib/craftplan_web/live/manage/inventory_live/index.ex:320` – `<% day_balance = Enum.at(material_data.balance_cells, index) %>` caches the balance for the current table column so it can be reused in the surrounding markup.
- `lib/craftplan_web/live/manage/inventory_live/index.ex:321` – `<% status = forecast_status(day_quantity, day_balance) %>` stores the forecast status badge value for the same column.
- `lib/craftplan_web/live/manage/overview_live.ex:315` – `<% day = List.first(@days_range) %>` keeps today’s grouped date so the header and Kanban logic can reuse it without repeating the lookup.
- `lib/craftplan_web/live/manage/overview_live.ex:340` – `<% kanban = get_kanban_columns_for_day(day, @production_items) %>` builds the Kanban columns for the active day before rendering the 3-column board.
- `lib/craftplan_web/live/manage/product_live/form_component_recipe.ex:104` – `<% material = material_for_form(@materials_map, components_form) %>` resolves the selected material for each component row so the template can show its name/link if present.

## Craftday scope

There is no `lib/craftday_web/` directory in this repository—only the `lib/craftday_web.ex` entrypoint exists, and it defines macro helpers (no inline templates). Thus, no `<% var = ... %>` bindings were found under that scope.
