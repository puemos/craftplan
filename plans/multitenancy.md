# Multi-Organizational Tenancy Implementation Plan

## Status
- [x] Organization domain foundations
- [x] Organization-aware data model
- [ ] Authentication & membership
- [ ] Web boundary propagation
- [ ] Operations & observability
- [ ] Testing & documentation

## 1. Organization Domain Foundations

### 1.1 Organization resource and schema
- Create `lib/craftplan/organizations/organization.ex` Ash resource for organizations with attributes `name`, `slug`, `status`, `billing_plan`, and `preferences`.
- Generate migration `priv/repo/migrations/*_create_organizations.exs` defining `organizations` table (UUID primary key, unique slug, JSONB preferences).
- Expose lookup helpers (`:lookup_by_slug`, `:list_active`) through the `Craftplan.Organizations` domain.

### 1.2 Organization context plumbing
- Introduce `Craftplan.Types.OrganizationContext` struct containing the loaded organization, feature flags, timezone, locale, billing, and branding metadata.
- Add helper in the organizations domain to build the organization context struct.
- Document relationships between organizations and other contexts to enforce consistent organization_id usage.

### 1.3 Provisioning flow
- Implement `Craftplan.Organizations.Provisioning` service to create organizations with preference defaults and future hooks for bootstrapping domain data.
- Provide mix task `mix craftplan.organizations.create` to run provisioning flow from CLI.
- Extend seeds with multi-organization examples.

## 2. Organization-Aware Data Model

### 2.1 Organization foreign keys
- [x] Add an `organization_id` reference to catalog products as the first step toward scoping core resources.
- [x] Add `organization_id` attribute/relationship to remaining Ash resources (inventory, orders, CRM).
- [x] Generate migrations adding foreign keys and composite uniqueness constraints per resource (tighten nullability + indexes).

### 2.2 Ash multitenancy policies
- [x] Configure `multitenancy` blocks with `strategy :attribute` so Ash enforces organization scoping automatically.
- [ ] Update policies to require matching `actor(:organization_id)` for reads/writes.
- [x] Provide helpers to set organization context on queries and changesets.
- [x] Normalize actors derived from user structs so organization-aware policies can reuse the same helper in web flows.

## 3. Authentication & Membership

- Extend `Accounts.User` with organization relationships and membership join resource.
- Scope authentication flows to require organization context (subdomain, invite, or signup form).
- Ensure sessions and tokens include organization identifiers.
- Design a self-service onboarding flow that can register an organization and its first admin:
  - Build a signup service that provisions an organization and associated admin user in a single transaction.
  - Expose a Phoenix LiveView for the signup form (`/register`) that captures organization + admin details and stores them via the signup service.
  - Send confirmation/invite emails after signup and redirect the new admin into their organization's base path once confirmed.

## 4. Web Boundary Propagation

- [x] Retired the legacy public catalog/cart/checkout flows to focus on authenticated, organization-scoped navigation.
- Introduce a base-path tenant resolution: `/:organization_slug/...` becomes the canonical entry point for authenticated routes. The router will scope management routes beneath this slug so every request carries the organization identifier in the URL.
- Add plugs to resolve the organization from the base path segment, set the Ash tenant (`organization.id`), and persist a lightweight `organization_context` for downstream consumers.
- [x] Provide organization-aware path helpers (`CraftplanWeb.LiveOrganization.scoped_path/3`) so LiveViews can generate URLs that honor the eventual base path.
- Use LiveView `on_mount` hooks to assign organization context to sockets, ensuring path helpers and components can reference `@organization_slug` and `@organization_base_path` when generating links.
- Update LiveViews to load data with organization context and render organization-specific branding.

## 5. Operations & Observability

- Build provisioning automation and organization management tasks.
- Backfill existing data with default organization IDs.
- Tag telemetry/logging with organization information.

## 6. Testing & Documentation

- Add test helpers for running code within an organization context.
- Write multi-organization domain and LiveView tests to prevent data leakage.
- Document architecture, flows, and diagrams in `guides/tenancy.md` and resource snapshots.
