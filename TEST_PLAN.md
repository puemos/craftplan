E2E LiveView Interaction Test Plan

This plan focuses on end-to-end interaction tests at the LiveView boundary using Phoenix.LiveViewTest (no browser drivers). It enumerates key user actions to validate, expected outcomes, and tracks interaction coverage per route.

Scope & Approach
- Framework: `Phoenix.LiveViewTest` via `CraftdayWeb.ConnCase` and SQL sandbox.
- Goal: Validate interactive behaviors (submissions, events, navigation) and outcomes (flashes, patches, stream updates, persisted data).
- Out of scope: Real browser automation (Playwright/Wallaby/Hound/etc.) and non-LiveView controller pages.
- Note: Render coverage already exists; this pass prioritizes interactions.

Status Legend
- TODO — not implemented yet
- IN_PROGRESS — currently being implemented
- BLOCKED — waiting on dependency or clarification
- DONE — implemented and passing

Conventions (Interactions)
- Auth: store session via `AshAuthentication.Phoenix.Plug.store_in_session/2`; set `timezone` cookie when views rely on it.
- Use verified routes `~p"..."` and `live(conn, path, on_error: :warn)`.
- Prefer element-driven testing: `element/2`, `has_element?/2`, `render_change/2`, `render_submit/2`.
- Assert navigation with `assert_patch/2`; verify effects with `render/1` and DB reads when needed.
- Seed minimal resources via Ash (suppliers, materials, customers, products) to satisfy preconditions.

Implementation Phases
- [DONE] Render coverage + minimal flows
- [DONE] Session helpers and fixtures
- [IN_PROGRESS] Interaction coverage for staff/admin views
- [TODO] Edge cases (invalid input, boundary conditions)
- [TODO] Negative-path auth checks (blocked actions)

File Layout (proposed)
- `test/craftday_web/public_*_live_test.exs`
- `test/craftday_web/manage_*_live_test.exs`
- `test/support/live_fixtures.ex` (new): staff/admin, product, inventory item, order, purchase order, customer, supplier, etc.

Route Coverage & Status

Public LiveViews (no auth required)
- /catalog (CraftdayWeb.Public.CatalogLive.Index :index)
  - Interactions: navigate to product; verify active products present when seeded
  - Status: DONE (basic; see: test/craftday_web/public_catalog_live_test.exs)
- /catalog/:sku (CraftdayWeb.Public.CatalogLive.Show :show)
  - Interactions: add-to-cart updates flash and cart state
  - Status: DONE (see: test/craftday_web/public_catalog_live_test.exs)
- /cart (CraftdayWeb.Public.CartLive.Index :index)
  - Interactions: change quantity; remove item; clear cart via controller
  - Status: DONE (see: test/craftday_web/public_cart_live_test.exs)
- /checkout (CraftdayWeb.Public.CheckoutLive.Index :index)
  - Interactions: submit checkout (creates order), clears cart, flash shown
  - Status: DONE (see: test/craftday_web/public_checkout_live_test.exs)

Admin Settings (admin only)
- /manage/settings (CraftdayWeb.SettingsLive.Index :index)
  - Interactions: update general settings; flash + persistence
  - Status: TODO (render covered; see: test/craftday_web/manage_settings_live_test.exs)
- /manage/settings/general (SettingsLive.Index :general)
  - Interactions: submit general form; assert patch + values updated
  - Status: TODO (render covered)
- /manage/settings/allergens (SettingsLive.Index :allergens)
  - Interactions: add allergen; delete allergen; list refreshes
  - Status: TODO (render covered)
- /manage/settings/nutritional_facts (SettingsLive.Index :nutritional_facts)
  - Interactions: add nutritional fact; delete; list refreshes
  - Status: TODO (render covered)

Products (staff/admin)
- /manage/products (ProductLive.Index :index)
  - Interactions: delete product (stream delete + flash); row click navigates to show
  - Status: TODO (render covered; see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/new (ProductLive.Index :new)
  - Interactions: create product (form submit + stream insert)
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku (ProductLive.Show :show)
  - Interactions: change status via select; flash + persistence
  - Status: TODO (render covered)
- /manage/products/:sku/details (ProductLive.Show :details)
  - Interactions: edit via modal; save updates details
  - Status: TODO (render covered)
- /manage/products/:sku/recipe (ProductLive.Show :recipe)
  - Interactions: add material to recipe; remove row; totals reflect quantity
  - Status: DONE (add + save; see: test/craftday_web/manage_products_interactions_live_test.exs)
- /manage/products/:sku/nutrition (ProductLive.Show :nutrition)
  - Interactions: derived from recipe; verify after recipe changes
  - Status: TODO (tied to recipe interaction)
- /manage/products/:sku/photos (ProductLive.Show :photos)
  - Interactions: set featured; remove photo (upload interactions optional/mock)
  - Status: TODO (render covered)
- /manage/products/:sku/edit (ProductLive.Show :edit)
  - Interactions: submit edit form; assert patch + flash
  - Status: TODO (render covered)

Inventory (staff/admin)
- /manage/inventory (InventoryLive.Index :index)
  - Interactions: delete material (stream delete + flash); row click navigates to show
  - Status: TODO (render covered; see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/forecast (InventoryLive.Index :forecast)
  - Interactions: change week via controls; assert updates
  - Status: TODO (render covered)
- /manage/inventory/new (InventoryLive.Index :new)
  - Interactions: create material (form submit + stream insert)
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku (InventoryLive.Show :show)
  - Interactions: from show, navigate to edit and save minimal change
  - Status: TODO (render covered)
- /manage/inventory/:sku/details (InventoryLive.Show :details)
  - Interactions: none (summary)
  - Status: N/A
- /manage/inventory/:sku/allergens (InventoryLive.Show :allergens)
  - Interactions: select allergens and save (flash + reload)
  - Status: DONE (see: test/craftday_web/manage_inventory_interactions_live_test.exs)
- /manage/inventory/:sku/nutritional_facts (InventoryLive.Show :nutritional_facts)
  - Interactions: add fact; remove fact; save (flash + reload)
  - Status: TODO (render covered)
- /manage/inventory/:sku/stock (InventoryLive.Show :stock)
  - Interactions: none (read-only)
  - Status: N/A
- /manage/inventory/:sku/edit (InventoryLive.Show :edit)
  - Interactions: submit edit form; assert patch + flash
  - Status: TODO (render covered)
- /manage/inventory/:sku/adjust (InventoryLive.Show :adjust)
  - Interactions: submit add/subtract/set_total; verify stock changes and flash
  - Status: DONE (set_total; see: test/craftday_web/manage_inventory_interactions_live_test.exs)

Orders (staff/admin)
- /manage/orders (OrderLive.Index :index)
  - Interactions: switch views (table/calendar); prev/next/today; apply filters; open/close event modal
  - Status: DONE (basic switch + today; see: test/craftday_web/manage_orders_interactions_live_test.exs)
- /manage/orders/new (OrderLive.Index :new)
  - Interactions: add product row; change quantity; submit order; stream insert + flash
  - Status: DONE (single item; see: test/craftday_web/manage_orders_interactions_live_test.exs)
- /manage/orders/:reference (OrderLive.Show :show)
  - Interactions: none (summary)
  - Status: N/A
- /manage/orders/:reference/details (OrderLive.Show :details)
  - Interactions: edit order (modal); save; flash + persistence
  - Status: TODO (render covered)
- /manage/orders/:reference/items (OrderLive.Show :items)
  - Interactions: change item status to done; assert consume confirmation modal; confirm consume; flash + stock changes
  - Status: TODO (render covered)
- /manage/orders/:reference/edit (OrderLive.Show :edit)
  - Interactions: submit edit; patch + flash
  - Status: TODO (render covered)
- /manage/orders/:reference/invoice (OrderLive.Invoice :show)
  - Interactions: none (read-only)
  - Status: N/A

Purchasing (staff/admin)
- /manage/purchasing (PurchasingLive.Index :index)
  - Interactions: receive PO (button click) updates status + inventory; flash
  - Status: TODO (render covered; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/new (PurchasingLive.Index :new)
  - Interactions: create PO (form submit + flash + appears in list)
  - Status: DONE (see: test/craftday_web/manage_purchasing_interactions_live_test.exs)
- /manage/purchasing/suppliers (PurchasingLive.Suppliers :index)
  - Interactions: navigate to edit on row click
  - Status: DONE (covered by modal tests; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/suppliers/new (PurchasingLive.Suppliers :new)
  - Interactions: create supplier (form submit + flash)
  - Status: TODO (render covered)
- /manage/purchasing/suppliers/:id/edit (PurchasingLive.Suppliers :edit)
  - Interactions: edit supplier and save (flash)
  - Status: TODO (render covered)
- /manage/purchasing/:po_ref/items (PurchasingLive.Show :items)
  - Interactions: add PO item; verify table updates; flash + modal close
  - Status: DONE (see: test/craftday_web/manage_purchasing_interactions_live_test.exs)
- /manage/purchasing/:po_ref (PurchasingLive.Show :show)
  - Interactions: mark received; redirect back with status updated
  - Status: TODO (render covered)
- /manage/purchasing/:po_ref/add_item (PurchasingLive.Show :add_item)
  - Interactions: add item form submit
  - Status: TODO (render covered)

Customers (staff/admin)
- /manage/customers (CustomerLive.Index :index)
  - Interactions: navigate to show on row click
  - Status: TODO (render covered; see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/new (CustomerLive.Index :new)
  - Interactions: create customer (form submit + stream insert)
  - Status: TODO (render covered)
- /manage/customers/:reference (CustomerLive.Show :show)
  - Interactions: none (summary)
  - Status: N/A
- /manage/customers/:reference/details (CustomerLive.Show :details)
  - Interactions: none (summary)
  - Status: N/A
- /manage/customers/:reference/orders (CustomerLive.Show :orders)
  - Interactions: click "New Order" navigates to orders/new with customer
  - Status: DONE (see: test/craftday_web/manage_customers_interactions_live_test.exs)
- /manage/customers/:reference/statistics (CustomerLive.Show :statistics)
  - Interactions: none (summary)
  - Status: N/A
- /manage/customers/:reference/edit (CustomerLive.Index :edit)
  - Interactions: submit edit; assert patch + flash
  - Status: TODO (render covered)

Production (staff/admin)
- /manage/production (PlanLive.Index :index)
  - Interactions: table links navigate; metrics reflect seeds
  - Status: TODO (render covered; see: test/craftday_web/manage_production_live_test.exs)
- /manage/production/schedule (PlanLive.Index :schedule)
  - Interactions: change schedule view (week/day); prev/next/today update
  - Status: TODO (render covered)
- /manage/production/make_sheet (PlanLive.Index :make_sheet)
  - Interactions: "Consume All Completed" performs consumption (flash)
  - Status: TODO (render covered)
- /manage/production/materials (PlanLive.Index :materials)
  - Interactions: open material details modal; verify quantities
  - Status: TODO (render covered)

Notes & Risks
- Role enforcement is implemented via `CraftdayWeb.LiveUserAuth` `on_mount`; tests set `:current_user` on the conn to satisfy guards.
- Some interactions may require additional fixtures (e.g., products for orders, suppliers for purchasing). Add focused helpers in `test/support/live_fixtures.ex` and keep them minimal.
- If any route requires non-trivial prerequisites, mark as BLOCKED with a note until helpers are in place.

Execution
- Run all: `mix test`.
- Run subset by area while iterating on interactions:
  - Products: `mix test test/craftday_web/manage_products_live_test.exs`
  - Inventory: `mix test test/craftday_web/manage_inventory_live_test.exs`
  - Orders: `mix test test/craftday_web/manage_orders_live_test.exs`
  - Purchasing: `mix test test/craftday_web/manage_purchasing_live_test.exs`
  - Customers: `mix test test/craftday_web/manage_customers_live_test.exs`
  - Production: `mix test test/craftday_web/manage_production_live_test.exs`
