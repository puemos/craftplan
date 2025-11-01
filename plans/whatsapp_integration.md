# WhatsApp Integration System Design

## Objective

Embed WhatsApp Business Platform inside Craftplan so owners can link their WABA, push catalog items, exchange threaded messages, and automatically open/advance orders — all while laying the groundwork for Shopify, WooCommerce, or generic GraphQL/REST connectors.

## System Overview

1. **Integration Domain (Ash):** New `Craftplan.Integrations` context governs providers, connections, channels, conversations, messages, and raw events. All edge-state (tokens, webhook secrets, template ids) lives inside Ash resources with `changes` enforcing invariants.
2. **Provider Behaviour:** A behaviour (`Craftplan.Integrations.Provider`) expresses the contract each external system must satisfy. WhatsApp implements it now; Shopify/WooCommerce will simply add modules later without touching the rest of the app.
3. **Integration Supervisor:** A `DynamicSupervisor` spawns per-connection workers responsible for token refresh, template caching, and reliable message delivery. Workers subscribe to Ash notifications so LiveViews/Flows just call the behaviour.
4. **Webhook & Event Pipeline:** Phoenix accepts Meta’s verification challenge, validates `X-Hub-Signature-256`, stores each payload as an `IntegrationEvent`, and processes downstream via Ash Flows (or Oban jobs) to mutate CRM conversations, messages, orders, and inventory.
5. **UI Surfaces:** `SettingsLive.Integrations` handles OAuth linking + status, CRM LiveViews stream conversations/messages, and Catalog/Orders LiveViews expose “Send via WhatsApp” affordances that call the provider behaviour.

## Domain Modeling

| Resource       | Purpose                                                                                          | Key Attributes                                                                                                    | Notable Actions                                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `Provider`     | Enumerates integration types (`:whatsapp_cloud`, `:shopify`, `:woocommerce`, `:custom_webhook`). | `code`, `display_name`, `capabilities` (array of atoms).                                                          | `read :list_active`, seeded records.                                                                                       |
| `Connection`   | One tenant ↔ provider link storing auth and config.                                             | `company_id`, `provider_id`, `status`, `settings` (encrypted map), `token`, `refresh_token`, metadata timestamps. | `create :link`, `update :rotate_token`, `read :by_company`. Changes enforce unique active connection per provider+company. |
| `Channel`      | Public-facing endpoint (WhatsApp phone number, Shopify store url).                               | `connection_id`, `identifier`, `label`, `enabled?`.                                                               | Manage via `manage_relationship` on `Connection`.                                                                          |
| `Conversation` | Thread between a channel and CRM contact.                                                        | `channel_id`, `contact_id`, `last_message_at`, `open_order_id`.                                                   | `read :recent_for_company`, `read :by_contact`.                                                                            |
| `Message`      | Individual inbound/outbound unit.                                                                | `conversation_id`, `direction`, `payload` (JSON), `provider_message_id`, `status`, `error`.                       | `create :ingest_inbound`, `create :enqueue_outbound`, `action :mark_status`.                                               |
| `Event`        | Raw webhook body + metadata for auditing/replay.                                                 | `connection_id`, `payload`, `event_type`, `processed_at`, `attempts`.                                             | `action :mark_processed`, `action :retry_later`.                                                                           |

Each resource derives forms via `AshPhoenix.Form` so LiveViews stay declarative.

## Provider Behaviour

```elixir
@callback authorize(%Connection{}, params()) ::
            {:ok, %Connection{}} | {:error, term()}
@callback sync_catalog(%Connection{}, opts()) ::
            {:ok, [Catalog.Product.t()]} | {:error, term()}
@callback send_message(%Connection{}, %Conversation{}, payload()) ::
            {:ok, %Message{}} | {:error, term()}
@callback handle_event(%Connection{}, %IntegrationEvent{}) ::
            {:ok, term()} | {:error, term()}
```

- WhatsApp implementation wraps Graph API endpoints (`/{phone-number-id}/messages`, `/{waba-id}/message_templates`, `/{catalog-id}/batch`).
- Shopify/WooCommerce will implement the same callbacks, so Catalog/Order flows just call `ProviderRouter.dispatch(connection, :sync_catalog, opts)`.

## Runtime Components

- **Integration Supervisor (`Craftplan.Integrations.Supervisor`):** Starts a `Registry` and a `DynamicSupervisor`.
- **Connection Worker (`Craftplan.Integrations.Worker`):** Owns a single connection, caches tokens, schedules refreshes, and exposes `via_tuple(connection_id)` for synchronous calls (backed by `GenServer.call` with back-pressure).
- **Event Processor:** Ash Flow (or Oban worker) that consumes `IntegrationEvent` records, invokes `Provider.handle_event/2`, and writes `Message`, `Conversation`, and `Order` updates inside a single Ash transaction to keep CRM state consistent.
- **HTTP Client:** Wrap in `Craftplan.Integrations.HTTP` (Req/Tesla) with retry and telemetry hooks so all providers inherit consistent logging and circuit breaking.

## External Flow

1. **OAuth & Setup**
   - Settings LiveView starts Meta OAuth (scoped to `business_management`, `whatsapp_business_messaging`, `whatsapp_business_management`).
   - Callback exchanges the code for a long-lived token; Ash action `Connection.link` persists token, WABA id, phone-number id, webhook secret.
   - Worker registers webhook subscription using stored callback URL (`/webhooks/meta_whatsapp`).
2. **Messaging**
   - Outbound: CRM UI calls `send_message/4` → Worker hits `/messages`, stores `Message` with `status=:pending`. Status updates come from webhooks.
   - Inbound: Webhook payload (`messages`, `statuses`, `message_template_status_update`) saved as `Event`, processed to upsert contacts (`Craftplan.CRM.Contact.upsert_for_phone/2`), create/open conversations, persist messages, and optionally trigger order flows.
3. **Catalog Sync**
   - Worker pulls Craftplan catalog via `Craftplan.Catalog.Product.list_for_company/1`, transforms into WhatsApp batch requests, stores `product_retailer_id` on SKU attributes.
   - SKU changes emit Ash notifications; Worker listens and re-syncs affected products.
4. **Order Automation**
   - `handle_event/2` inspects interactive reply payloads (button/list). It launches an Ash Flow:
     1. Upsert CRM contact + address.
     2. `Orders.Order.start_from_conversation/2` to create or update a draft order.
     3. Reserve inventory via existing inventory domain actions.
     4. Trigger template message (order confirmation, payment link).

## Security, Observability, Reliability

- Encrypt all tokens (`Ash.Type.Map` + `encrypted? true` or custom type hooking into Cloak/Vault). Redact logs via custom `Inspect`.
- Store webhook signature secret per connection and validate every request; send `403` + alert on failure.
- Provide telemetry events (`[:craftplan, :integrations, :http, ...]`) and dashboards (Grafana) for API latency, errors, and rate limits.
- Backoff + retry strategy: exponential backoff with jitter for send failures, dead-letter `IntegrationEvent` after `N` retries with operator alert.
- Allow manual reprocessing: admin UI button to replay a failed event (`Event.retry_later` action).

## Extensibility Hooks

- Form schemas read provider metadata to render custom fields (e.g., Shopify store URL, WooCommerce consumer key). No per-provider templates in LiveView.
- `Provider.capabilities` advertised (e.g., `[:messaging, :catalog_push, :orders_webhook]`) so UI only exposes relevant buttons.
- Provide `CustomWebhookProvider` that simply posts JSON payloads to a user-defined endpoint, covering generic REST/GraphQL integrations later.

## Delivery Plan

1. **Domain & Infrastructure**
   - Scaffold Ash resources + migrations.
   - Seed Provider records and expose `Craftplan.Integrations` context.
   - Add `IntegrationSupervisor` to application tree and notification subscriptions.
2. **Settings LiveView + OAuth**
   - Build `SettingsLive.Integrations` (list connections, add/edit form).
   - Implement Meta OAuth controller + callback storing tokens via `Connection.link`.
   - Support connection health checks (channel reachable? webhook verified?).
3. **Webhook Endpoint & Event Store**
   - Add `/webhooks/meta_whatsapp` controller responding to verification challenge.
   - Persist events, validate signatures, enqueue processing jobs via Ash Flow/Oban.
4. **Messaging Endpoints**
   - Implement provider behaviour for WhatsApp send + status handling.
   - Update CRM LiveViews to stream conversations/messages and allow replies with attachments/templates.
5. **Catalog Sync**
   - Map Craftplan `Catalog.Product` + `Inventory.Sku` to WhatsApp Commerce objects.
   - Introduce bulk sync action + delta sync triggered from product updates.
6. **Order Automation Flow**
   - Build Ash Flow orchestrating contact upsert → order mutation → inventory reservation → message template send.
   - Surface per-conversation order snippets + quick actions (mark paid, fulfill).
7. **Operational Hardening**
   - Token rotation, retry policies, telemetry dashboards, and runbooks.
   - Document rollout steps and add feature flags for early access.
8. **Future Provider Ready**
   - Publish behaviour usage guide, create skeletal Shopify/WooCommerce modules with `:not_implemented` stubs, and ensure LiveView forms read provider metadata dynamically.
