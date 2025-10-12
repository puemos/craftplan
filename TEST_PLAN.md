E2E LiveView Test Plan

This plan covers end-to-end page flows at the LiveView boundary using Phoenix.LiveViewTest only (no browser drivers). It enumerates every LiveView route, the minimum happy-path interactions to verify, and tracks status for each.

Scope & Approach
- Framework: `Phoenix.LiveViewTest` via `CraftdayWeb.ConnCase` and SQL sandbox.
- Goal: For every LiveView route, assert it renders for the correct role, enforces auth, and exercises one core interaction when applicable.
- Out of scope: Real browser automation (Playwright/Wallaby/Hound/etc.) and non-LiveView controller pages.

Status Legend
- TODO — not implemented yet
- IN_PROGRESS — currently being implemented
- BLOCKED — waiting on dependency or clarification
- DONE — implemented and passing

Conventions
- Public pages: `conn = Plug.Conn.assign(conn, :current_user, nil)`.
- Staff pages: `conn = Plug.Conn.assign(conn, :current_user, Craftday.DataCase.staff_actor())`.
- Admin pages: `conn = Plug.Conn.assign(conn, :current_user, Craftday.DataCase.admin_actor())`.
- Use verified routes `~p"..."` and `live(conn, path, on_error: :warn)`.
- Seed minimal domain data with Ash resources (using staff/admin actor as required).
- Cart-backed pages: create a cart and set `conn = init_test_session(conn, %{cart_id: cart.id})`.
- Place shared helpers in `test/support` as needed (e.g., product/order factories).

Implementation Phases
- [DONE] Draft plan and route coverage
- [TODO] Add common fixtures/helpers in `test/support`
- [DONE] Cover public LiveViews (fill any gaps)
- [DONE] Cover admin Settings LiveViews
- [DONE] Cover Products LiveViews
- [DONE] Cover Inventory LiveViews
- [TODO] Cover Orders LiveViews (incl. invoice)
- [TODO] Cover Purchasing LiveViews
- [TODO] Cover Customers LiveViews
- [TODO] Cover Production LiveViews

File Layout (proposed)
- `test/craftday_web/public_*_live_test.exs`
- `test/craftday_web/manage_*_live_test.exs`
- `test/support/live_fixtures.ex` (new): staff/admin, product, inventory item, order, purchase order, customer, supplier, etc.

Route Coverage & Status

Public LiveViews (no auth required)
- /catalog (CraftdayWeb.Public.CatalogLive.Index :index)
  - Verify: renders list; shows active product name when one exists
  - Status: DONE (see: test/craftday_web/public_catalog_live_test.exs)
- /catalog/:sku (CraftdayWeb.Public.CatalogLive.Show :show)
  - Verify: renders; submit add-to-cart updates flash
  - Status: DONE (see: test/craftday_web/public_catalog_live_test.exs)
- /cart (CraftdayWeb.Public.CartLive.Index :index)
  - Verify: renders existing cart; quantity update persists
  - Status: DONE (see: test/craftday_web/public_cart_live_test.exs)
- /checkout (CraftdayWeb.Public.CheckoutLive.Index :index)
  - Verify: checkout form submission places order; clears cart feedback
  - Status: DONE (see: test/craftday_web/public_checkout_live_test.exs)

Admin Settings (admin only)
- /manage/settings (CraftdayWeb.SettingsLive.Index :index)
  - Verify: renders for admin; unauthenticated redirects to /sign-in
  - Status: DONE (see: test/craftday_web/manage_settings_live_test.exs)
- /manage/settings/general (SettingsLive.Index :general)
  - Verify: renders tab; basic save interaction if present
  - Status: DONE (see: test/craftday_web/manage_settings_live_test.exs)
- /manage/settings/allergens (SettingsLive.Index :allergens)
  - Verify: renders allergens UI; basic update interaction
  - Status: DONE (see: test/craftday_web/manage_settings_live_test.exs)
- /manage/settings/nutritional_facts (SettingsLive.Index :nutritional_facts)
  - Verify: renders nutrition settings; basic update interaction
  - Status: DONE (see: test/craftday_web/manage_settings_live_test.exs)

Products (staff/admin)
- /manage/products (ProductLive.Index :index)
  - Verify: renders list; unauthenticated redirects (covered generically); minimal filter/search if present
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/new (ProductLive.Index :new)
  - Verify: new product form shows; create minimal product
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku (ProductLive.Show :show)
  - Verify: loads product; shows key details
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku/details (ProductLive.Show :details)
  - Verify: details tab renders
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku/recipe (ProductLive.Show :recipe)
  - Verify: recipe tab renders; add an ingredient if present
  - Status: DONE (render only; see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku/nutrition (ProductLive.Show :nutrition)
  - Verify: nutrition tab renders; update if present
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku/photos (ProductLive.Show :photos)
  - Verify: photos tab renders
  - Status: DONE (see: test/craftday_web/manage_products_live_test.exs)
- /manage/products/:sku/edit (ProductLive.Show :edit)
  - Verify: edit form renders; submit minimal change
  - Status: DONE (render only; see: test/craftday_web/manage_products_live_test.exs)

Inventory (staff/admin)
- /manage/inventory (InventoryLive.Index :index)
  - Verify: renders list; minimal filter/search if present
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/forecast (InventoryLive.Index :forecast)
  - Verify: forecast tab renders
  - Status: DONE (covered by index render with tabs)
- /manage/inventory/new (InventoryLive.Index :new)
  - Verify: new material form renders; create minimal material
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku (InventoryLive.Show :show)
  - Verify: shows material/product inventory
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/details (InventoryLive.Show :details)
  - Verify: details tab renders
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/allergens (InventoryLive.Show :allergens)
  - Verify: allergens tab renders; basic update
  - Status: DONE (render only; see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/nutritional_facts (InventoryLive.Show :nutritional_facts)
  - Verify: nutrition tab renders; basic update
  - Status: DONE (render only; see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/stock (InventoryLive.Show :stock)
  - Verify: stock tab renders
  - Status: DONE (see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/edit (InventoryLive.Show :edit)
  - Verify: edit form renders; submit minimal change
  - Status: DONE (render only; see: test/craftday_web/manage_inventory_live_test.exs)
- /manage/inventory/:sku/adjust (InventoryLive.Show :adjust)
  - Verify: adjustment form renders; submit minimal adjustment
  - Status: DONE (render only; see: test/craftday_web/manage_inventory_live_test.exs)

Orders (staff/admin)
- /manage/orders (OrderLive.Index :index)
  - Verify: renders list; unauthenticated redirects (generic coverage exists)
  - Status: DONE (see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/new (OrderLive.Index :new)
  - Verify: new order form renders; create minimal order
  - Status: DONE (render only; see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/:reference (OrderLive.Show :show)
  - Verify: shows order header
  - Status: DONE (see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/:reference/details (OrderLive.Show :details)
  - Verify: details tab renders; edit detail
  - Status: DONE (render only; see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/:reference/items (OrderLive.Show :items)
  - Verify: items tab renders; add/remove line item
  - Status: DONE (render only; see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/:reference/edit (OrderLive.Show :edit)
  - Verify: edit form renders; submit minimal change
  - Status: DONE (render only; see: test/craftday_web/manage_orders_live_test.exs)
- /manage/orders/:reference/invoice (OrderLive.Invoice :show)
  - Verify: invoice renders
  - Status: DONE (see: test/craftday_web/manage_orders_live_test.exs)

Purchasing (staff/admin)
- /manage/purchasing (PurchasingLive.Index :index)
  - Verify: renders list
  - Status: DONE (see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/new (PurchasingLive.Index :new)
  - Verify: new PO form renders; create minimal PO
  - Status: DONE (render only; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/suppliers (PurchasingLive.Suppliers :index)
  - Verify: suppliers list renders
  - Status: DONE (see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/suppliers/new (PurchasingLive.Suppliers :new)
  - Verify: new supplier form; create minimal supplier
  - Status: DONE (render only; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/suppliers/:id/edit (PurchasingLive.Suppliers :edit)
  - Verify: edit supplier form
  - Status: DONE (render only; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/:po_ref/items (PurchasingLive.Show :items)
  - Verify: PO items tab; add item
  - Status: DONE (render only; see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/:po_ref (PurchasingLive.Show :show)
  - Verify: PO summary renders
  - Status: DONE (see: test/craftday_web/manage_purchasing_live_test.exs)
- /manage/purchasing/:po_ref/add_item (PurchasingLive.Show :add_item)
  - Verify: add-item screen renders
  - Status: DONE (render only; see: test/craftday_web/manage_purchasing_live_test.exs)

Customers (staff/admin)
- /manage/customers (CustomerLive.Index :index)
  - Verify: renders list
  - Status: DONE (see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/new (CustomerLive.Index :new)
  - Verify: new customer form; create minimal customer
  - Status: DONE (render only; see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/:reference (CustomerLive.Show :show)
  - Verify: customer details render
  - Status: DONE (see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/:reference/details (CustomerLive.Show :details)
  - Verify: details tab renders
  - Status: DONE (see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/:reference/orders (CustomerLive.Show :orders)
  - Verify: orders tab renders
  - Status: DONE (see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/:reference/statistics (CustomerLive.Show :statistics)
  - Verify: statistics tab renders
  - Status: DONE (see: test/craftday_web/manage_customers_live_test.exs)
- /manage/customers/:reference/edit (CustomerLive.Index :edit)
  - Verify: edit form renders; submit minimal change
  - Status: DONE (render only; see: test/craftday_web/manage_customers_live_test.exs)

Production (staff/admin)
- /manage/production (PlanLive.Index :index)
  - Verify: schedule/plan overview renders
  - Status: DONE (see: test/craftday_web/manage_production_live_test.exs)
- /manage/production/schedule (PlanLive.Index :schedule)
  - Verify: schedule tab renders
  - Status: DONE (see: test/craftday_web/manage_production_live_test.exs)
- /manage/production/make_sheet (PlanLive.Index :make_sheet)
  - Verify: make sheet tab renders
  - Status: DONE (see: test/craftday_web/manage_production_live_test.exs)
- /manage/production/materials (PlanLive.Index :materials)
  - Verify: materials tab renders
  - Status: DONE (see: test/craftday_web/manage_production_live_test.exs)

Notes & Risks
- Role enforcement is implemented via `CraftdayWeb.LiveUserAuth` `on_mount`; tests set `:current_user` on the conn to satisfy guards.
- Some interactions may require additional fixtures (e.g., products for orders, suppliers for purchasing). Add focused helpers in `test/support/live_fixtures.ex` and keep them minimal.
- If any route requires non-trivial prerequisites, mark as BLOCKED with a note until helpers are in place.

Execution
- Run all: `mix test`.
- Run subset: `mix test test/craftday_web/manage_products_live_test.exs` (or specific file).
