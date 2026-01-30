# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
mix setup              # Full setup: deps, ash.setup, assets, seeds
mix phx.server         # Start dev server at localhost:4000
mix test               # Run all tests (runs ash.setup --quiet first)
mix test path/to/test.exs            # Run a single test file
mix test path/to/test.exs:42         # Run a specific test at line
mix format             # Format all code (Styler, Spark, Tailwind, HEEx)
mix dialyzer           # Static type analysis
mix ash.setup          # Run migrations + Ash introspection
mix ash.reset          # Drop, create, migrate, seed
docker-compose up -d   # Start PostgreSQL 16 + MinIO (S3-compatible storage)
```

## Architecture

Craftplan is an ERP for small-scale manufacturers built on **Ash Framework + Phoenix LiveView + PostgreSQL**.

### Domain Structure (Ash Domains)

Each domain is an `Ash.Domain` containing related `Ash.Resource` modules:

- **Craftplan.Accounts** — Users, authentication (AshAuthentication)
- **Craftplan.Catalog** — Products, BOMs (Bill of Materials), BOM components, labor steps, BOM rollups
- **Craftplan.Orders** — Orders, OrderItems, ProductionBatches, batch allocations, consumption workflow
- **Craftplan.Inventory** — Materials, Lots, Movements (consume/receive/adjust), forecasting
- **Craftplan.CRM** — Customers, suppliers
- **Craftplan.Settings** — App configuration

### Resource Pattern

All domain entities are Ash Resources using `AshPostgres.DataLayer` with `Ash.Policy.Authorizer`. Business logic is encoded as Ash actions with custom changes (in `changes/` subdirectories) and validations. Domain modules define code interface functions via `:define`.

### Web Layer

- **Router**: `lib/craftplan_web/router.ex`
- **LiveViews**: `lib/craftplan_web/live/manage/` — main app pages (overview, products, orders, inventory, batches, etc.)
- **Components**: `lib/craftplan_web/components/` — reusable UI (core, forms, data_vis, page, layouts)
- Auth via `on_mount` hooks using AshAuthenticationPhoenix

### Key Business Flows

- **Production Batching**: Orders → OrderItems allocated to ProductionBatches → consume materials from Lots → complete with produced qty and cost snapshot
- **BOM Versioning**: Edit latest version only; older versions are read-only
- **Inventory Forecasting**: `Craftplan.InventoryForecasting` predicts material demand from upcoming orders

## Testing

- **Test support**: `test/support/data_case.ex` (database tests), `test/support/conn_case.ex` (LiveView tests), `test/support/factory.ex`
- **Factory** uses Ash actions directly to create test entities (products, materials, BOMs, customers, orders)
- **Helper functions**: `staff_actor()` and `admin_actor()` create test users with appropriate roles
- **LiveView tests** use `Phoenix.LiveViewTest` with `live/2`, `element/2`, `render_click/1`, `form/3`, `render_submit/1`
- Tests use PostgreSQL sandbox in manual mode (async-compatible)

## Formatting & Style

- **Styler** enforces Elixir code style (AST-based linter + formatter)
- **Spark.Formatter** handles Ash DSL block ordering (section order defined in config)
- **TailwindFormatter** orders CSS classes
- **Phoenix.LiveView.HTMLFormatter** formats HEEx templates
- All four run via `mix format`

## Commit Convention

Commits follow the pattern: `type(scope): description` (e.g., `feat(batching):`, `ui(production):`, `fix(orders):`)
