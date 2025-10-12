Craftday Technical Plan — Security, Performance, and Web Consistency

Last updated: 2025‑10‑12

Progress
- Overall: [ ] Not started / [ ] Planned / [ ] In progress / [x] Done (phase 1)
- Workstreams
  - [x] WS1: Authorization & Policies
  - [x] WS2: Web Layer Actor/Context Consistency
  - [x] WS3: Public Checkout Hardening
  - [x] WS4: Performance & Indexes
  - [x] WS5: Testing & CI Guards
  - [ ] WS6: Admin Surface

Scope & Objective
- Establish default‑deny authorization across domains while preserving public storefront flows.
- Make LiveView/web calls consistent in passing actor/context to Ash so policies are enforceable.
- Improve query performance for order dashboards and search.
- Add tests to prevent regressions.

Stack Snapshot (evidence)
- Ash 3.6.2, AshPostgres 2.6.21, AshAuthentication 4.11.0 (mix.lock)
- Domains configured: config/config.exs:43
- LiveView routes with cart context/session: lib/craftday_web/router.ex:28–55, 90–170

Top Risks / Opportunities
1) Policies enforced; maintain actor/context discipline to avoid regressions.
2) Enhance negative-path tests (403s) to defend against future changes.
3) Orders indexes shipped; consider customer search improvements if needed.
4) Public checkout uses minimal actions; keep surface area tight.
5) Authentication config warning: choose session_identifier or require tokens.

--------------------------------------------------------------------
WS1 — Authorization & Policies
Status: [ ] Not started  [ ] In progress  [x] Done

Highlights
- Catalog.Product: public read limited to active/available; writes staff/admin (lib/craftday/catalog/product.ex)
- Settings.Settings: public read; updates admin (lib/craftday/settings/settings.ex)
- Orders.Order: adds :public_create (checkout) and :for_day (capacity) with policy bypass; other actions staff/admin (lib/craftday/orders/order.ex)
- Orders.OrderItem: :in_range read bypass (capacity), other actions staff/admin (lib/craftday/orders/order_item.ex)
- CRM.Customer: public create/update and get_by_email; other reads/destroys staff/admin (lib/craftday/crm/customer.ex)
- Inventory: Material public read (aggregates), Movement and writes staff/admin (lib/craftday/inventory/*)
- Cart.Cart/CartItem: context[:cart_id] guards; staff/admin bypass (lib/craftday/cart/*.ex)

Notes & Refs
- Policies: hexdocs.pm/ash/policies.html
- Authorizer: hexdocs.pm/ash/Ash.Policy.Authorizer.html

--------------------------------------------------------------------
WS2 — Web Layer Actor/Context Consistency
Status: [ ] Not started  [ ] In progress  [x] Done

Goals
- Ensure every Ash call from LiveView/web passes actor (staff sections) or context (anonymous cart).

Findings (patched)
- Production (manage) now passes actor when loading orders/materials
  - lib/craftday_web/live/manage/plan_live/index.ex:1087,1093 — actor passed to Production.fetch_orders_in_range/3
- Production helper accepts opts already; callers updated as above
  - lib/craftday/production.ex:13 — `fetch_orders_in_range/3` supports `actor:`

Implementation Approach
- Thread `actor: socket.assigns.current_user` on all manage LiveView reads/writes and Ash.load!/count
- Keep public cart reads/writes on context: %{cart_id: ...} (already applied across public LVs)

--------------------------------------------------------------------
WS3 — Public Checkout Hardening
Status: [ ] Not started  [ ] In progress  [x] Done

Highlights
- Order placement via :public_create; day count via :for_day; product capacity via OrderItem :in_range
- File: lib/craftday_web/live/public/checkout_live/index.ex

--------------------------------------------------------------------
WS4 — Performance & Indexes
Status: [ ] Not started  [ ] In progress  [x] Done

Goals
- Speed up list/calendars by indexing filter columns; improve name search.

Delivered
- Indexes on orders_orders: delivery_date, status, payment_status
  - priv/repo/migrations/20251012100000_add_order_filters_indexes.exs

Acceptance
- Orders list and calendar queries remain responsive with 50k+ rows.

--------------------------------------------------------------------
WS5 — Testing & CI Guards
Status: [ ] Not started  [ ] In progress  [x] Done

Goals
- Add policy tests and minimal LiveView auth flows to prevent regressions.

Delivered
- LiveView e2e smoke tests: public catalog/cart/checkout, manage-auth redirect
  - test/craftday_web/public_catalog_live_test.exs
  - test/craftday_web/public_cart_live_test.exs
  - test/craftday_web/public_checkout_live_test.exs
  - test/craftday_web/manage_auth_live_test.exs
- Test deps wired: mix.exs includes {:lazy_html, ">= 0.1.0", only: :test}

Suite Status
- Full suite passing locally: 29 tests, 0 failures.
- e2e LiveView tests cover public catalog/cart/checkout and manage auth redirect.

--------------------------------------------------------------------
WS6 — Admin Surface
Status: [ ] Not started  [ ] In progress  [ ] Done

Goals
- Enable AshAdmin (dev; optionally staff‑only) for faster inspection.

Implementation Approach
- lib/craftday_web/router.ex (dev scope): `forward "/admin", AshAdmin.Plug, otp_app: :craftday`

--------------------------------------------------------------------
Recently Completed
- Policies added (default‑deny, narrow public bypasses) across Catalog, Settings, Orders, CRM, Inventory, Cart
- Public checkout hardened to minimal actions and capacity checks
- Cart context established end‑to‑end in router/hooks and public LVs
- Orders filters indexed for performance
- LiveView e2e tests added for key public/manage flows

--------------------------------------------------------------------
Open Issues / Follow‑ups
- Add negative-path policy tests (403s) for deny scenarios (see backlog).
- Expand LiveView coverage for edge cases (capacity, tax inclusive paths).

--------------------------------------------------------------------
Next Actions (surgical patches)
- Optional: add policy tests for deny paths (cart cross-access, orders without actor)
- Minor cleanup: remove unused variables and INFO logs in public LVs; confirm no warnings in CI.

--------------------------------------------------------------------
Quick Run Targets
- mix deps.get && mix ecto.migrate
- mix test test/craftday/inventory/receiving_test.exs  # passing
- mix test test/craftday/production_facts_test.exs     # passing
- mix test test/craftday/orders/order_constraints_test.exs  # passing
- mix test test/craftday_web/public_checkout_live_test.exs  # passing
- mix test test/craftday_web/public_catalog_live_test.exs   # passing
- mix test test/craftday_web/public_cart_live_test.exs      # passing

--------------------------------------------------------------------
Backlog (prioritized)
- P1 Add negative policy tests (403s) for cart cross‑access — Effort: S — Impact: 4
- P1 Authentication config hardening — Effort: S — Impact: 4
  - Address AshAuthentication warning by either setting `authentication.session_identifier: :jti | :unsafe` or `tokens.require_token_presence_for_authentication?: true` (logs out users on change). Do in a maintenance window.
- P2 Staff/admin guardrails in other manage LVs (spot check) — Effort: S — Impact: 3
- P2 Customer search: consider trigram index and normalized search (optional) — Effort: M — Impact: 3
- P3 Dev AshAdmin surface in dev only — Effort: S — Impact: 2

Notes on Public Cart Test Stabilization
- Cause: Relationship load on Cart -> items returned [] under policy context, while listing items returned rows.
- Fixes applied:
  - LiveView now derives items via `Cart.list_cart_items!/1` and loads `:product` explicitly: lib/craftday_web/live/public/cart_live/index.ex
  - Test targets a stable form id `#update-item-<id>` and verifies the update using `Cart.list_cart_items!/1`.
  - Reverted server: true and removed runtime sandbox plug; LV tests run with default server: false (in‑process) and work reliably.
- P1 Fix actor passthroughs (Receiving + PlanLive) — Effort: S — Impact: 5 (done)
- P1 Test fixes (ProductionFacts, Orders constraints) — Effort: S — Impact: 5 (done)
- P2 Add negative policy tests (403s) for cart cross‑access — Effort: S — Impact: 4
- P2 Staff/admin guardrails in other manage LVs (spot check) — Effort: S — Impact: 3
- P3 Dev AshAdmin surface in dev only — Effort: S — Impact: 2

--------------------------------------------------------------------
Upgrade & Config Notes
- AshAuthentication warning observed during compilation: set `session_identifier` or require tokens to remove warning (logs out users when changed). Plan under backlog P1.
- If customer search becomes slow, prefer `pg_trgm` with a GIN index or split search into first/last name with btree indexes.

--------------------------------------------------------------------
Risk & Rollback
- Policies can be toggled per resource by removing authorizers in a hotfix; keep changes isolated per file.
- Public checkout uses separate actions (:public_create, :for_day) so we can roll back to staff‑only :create without touching storefront.

Notes for Implementers
- Validate each LiveView after enabling policies; failures present as empty reads (filtered) or 403 depending on configuration.
- Prefer Ash domain calls with `actor:` for manage paths; prefer `context:` for anonymous/cart checks.
