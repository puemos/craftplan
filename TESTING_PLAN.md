Testing Foundation Plan — Phoenix + LiveView + Ash + AshAuthentication

Last updated: 2025-10-18

Purpose
- Establish a durable, low-friction testing foundation compatible with `require_token_presence_for_authentication? true`.
- Reduce brittle assertions, centralize setup, and make auth predictable in tests.

Goals
- Stable sign-in in tests with token-backed sessions (no `:token` KeyError).
- Central factories for common domain entities (products, materials, recipes, customers, orders).
- Consistent passing of `actor` for Ash actions/policies.
- Prefer element selectors/IDs over raw text for LiveView assertions.

Constraints & Assumptions
- AshAuthentication tokens are enabled and stored (`store_all_tokens? true`) and required for auth.
- Tests run under SQL sandbox; data isolation is per-test.
- We do not add new deps; stick to standard ExUnit + Phoenix.LiveViewTest + Ash.

Architecture Overview
- test/support/auth_helpers.ex
  - `register_user!(role)` → returns a freshly registered user with `__metadata__.token`.
  - `ensure_token!(user)` → ensures returned user includes `__metadata__.token` (sign-in if missing).
  - `sign_in(conn, user)` → sets timezone cookie, stores token via `AshAuthentication.Phoenix.Plug.store_in_session/2`, assigns `:current_user`.
  - `sign_in_as(conn, role)` → convenience returning `{conn, user}`.

- test/support/factory.ex
  - `create_product!(attrs \\ %{})` (unique `:sku`).
  - `create_material!(attrs \\ %{})`, `add_allergen!(material, name)`.
  - `create_recipe!(product, components)` (components: `%{material_id, quantity}`).
  - `create_customer!(attrs \\ %{})`.
  - `create_order_with_items!(customer, items, opts)` (items: `%{product_id, quantity, unit_price}`).
  - Factories accept optional `actor`; default to a staff user.

- test/support/ash_helpers.ex
  - Thin wrappers to consistently pass `actor/context`:
    - `ash_create!(resource, action, attrs, actor \\ default_staff())`
    - `ash_update!(record, action, attrs, actor \\ default_staff())`
    - `ash_read!(resource, action, args \\ %{}, load \\ [], actor \\ default_staff())`

- test/support/conn_case.ex (augment)
  - Default timezone cookie: `"Etc/UTC"`.
  - Import `AuthHelpers` for easy sign-in.
  - Tag-based auto sign-in:
    - `@tag role: :staff | :admin` → setup signs in and provides `%{conn: conn, user: user}`.

- test/support/data_case.ex (augment)
  - `staff_actor/0` and `admin_actor/0` call `register_user!` to ensure token-bearing users.
  - Keep sandbox setup as-is.

LiveView Test Conventions
- Prefer selectors/IDs over raw text:
  - `assert has_element?(view, "#invoice-items")`
  - `assert has_element?(view, "[role=tablist]")`
- Use `render_submit/2`, `render_change/2`, `render_click/1` with targeted elements.
- Keep string assertions for fixed labels/IDs; avoid dynamic timestamp/currency text where possible.

Domain Test Conventions
- Test changes/validations with focused unit tests.
- Use factories for inputs; prefer clear `actor` intent.
- Use helpers to load minimal relationships required by the assertion.

Unique Data & Isolation
- Generate unique emails/SKUs with `System.unique_integer/1` or random bytes.
- Avoid reusing global fixtures to prevent token/session ambiguity.

Rollout Plan
1) Add support modules
   - `test/support/auth_helpers.ex`
   - `test/support/factory.ex`
   - `test/support/ash_helpers.ex`
   - Update `test/support/conn_case.ex` to import helpers and support `@tag role: ...`.
   - Update `test/support/data_case.ex` to use `register_user!`.

2) Migrate representative tests
   - Convert a few LiveView tests to use `@tag role: :staff` and remove ad-hoc sign-in.
   - Replace brittle text assertions with `has_element?/2` where feasible.
   - Replace inline resource creation with factories for clarity.

3) Migrate remaining tests incrementally
   - Standardize on helpers; remove duplicated sign-in code.
   - Ensure all Ash actions pass explicit `actor` when policies apply.

4) Optional Enhancements
   - Add Mox for external integrations (e.g., Stripe) to isolate network.
   - Add small assertion helpers for money/decimal formatting.
   - CI: consider warnings-as-errors for unused/brittle selectors.

Definition of Done
- No tests rely on manual session munging; all sign-ins use helpers and tokens.
- No `KeyError :token` or auth-related flakes.
- Common entities created via factories; sign-in patterns removed from test files.
- LiveView tests rely on selectors/IDs consistently.

Open Questions
- Do we want a short alias layer (e.g., `use Craftplan.Factory`) in tests for terseness?
- Should we disable `require_token_presence_for_authentication?` in `:test` for speed, or keep parity with prod? (Current plan keeps parity.)

Task Checklist
- [ ] Add `test/support/auth_helpers.ex` with register/sign-in helpers.
- [ ] Add `test/support/factory.ex` for domain entities.
- [ ] Add `test/support/ash_helpers.ex` wrappers.
- [ ] Update `test/support/conn_case.ex` for timezone + tag-based sign-in.
- [ ] Update `test/support/data_case.ex` to use `register_user!`.
- [ ] Convert 3 representative LiveView tests to the new pattern.
- [ ] Convert all remaining tests incrementally.
