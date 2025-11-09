# Production Batching & Plan UI

Last updated: 2025-11-09

## Objective

Move Craftplan to true batch‑centric production and a single Plan page for operators to select pending items (past → today), create/add batches, and track batches by status — with Ash-first actions, validations, and LiveView tests.

## Milestones

### M1 — Domain & Actions (Batch Core)

- [x] Add `Orders.OrderItemBatchAllocation` resource (join: batch ↔ order item) with validations
- [x] Extend `Orders.ProductionBatch` with snapshot + planning fields (status, planned/produced/scrap, notes; BOM snapshot)
- [x] Add batch actions: `:open`, `:open_with_allocations`, `:start`, `:consume`, `:complete`
- [x] Tag batch consumption with `ProductionBatchLot` for traceability
- [x] Aggregates on `OrderItem`: `planned_qty_sum`, `completed_qty_sum`
- [x] Tests: allocation math, status derivation, cost rounding

### M1.5 — Resource Actions & Validations (Ash-first)

- [x] `ProductionBatch` actions hardened:
  - [x] `create :open` → freeze BOM snapshot, generate `batch_code`, set status `:open`
  - [x] `create :open_with_allocations` → manage `allocations` in one call (uses `manage_relationship`)
  - [x] `update :start` → status `:in_progress`, set `started_at`
  - [x] `update :consume` → accepts `lot_plan`; change surfaces errors (before_action)
  - [x] `update :complete` → sets final fields; service runs in after_action and surfaces errors
- [x] `ProductionBatch` reads:
  - [x] `read :recent` (paged, newest first)
  - [x] `read :detail` (loads product, bom, allocations→order items, lots)
- [x] `OrderItemBatchAllocation` validations:
  - [x] Product match with batch product
  - [x] Non‑negative quantities; `completed_qty <= planned_qty`
  - [x] Guard rail: total planned across allocations ≤ item.quantity
- [ ] Deprecate per‑item `Orders.Consumption`; add `OrderItem.action :quick_complete` (follow‑up)

### M2 — Plan Page (Unified UI)

- [x] New Plan page at `/manage/production/plan` with two panels:
  - [x] Pending Items (left) now streams from an Ash list action, includes remaining calculations, and supports multi-select.
  - [x] Batches by Status (right) renders To Do / In Progress / Done lanes with summary cards.
- [x] “Add to Batch…” flow:
  - [x] Select items → Add to Batch modal → pick New or Existing open batch per product.
  - [x] Cross‑product selections auto group per product and create one batch per product.
- [ ] Drag & drop:
  - [ ] Supporting drop onto “New Batch” or an open batch card (product-match enforced) — future enhancement.
- [x] Replace daily planner toggle; navigation now roots to Plan with updated breadcrumb.
- [x] LiveView tests cover pending list rendering and Add to Batch modal interactions.

### M3 — Batch Detail Actions & Flows

- [ ] Batch Show: wire Start/Consume/Complete to Ash actions; consume supports lot plan capture
- [ ] Optional: `Ash.Flow` to orchestrate completion (costing + splits) transactionally
- [ ] LiveView tests for batch actions (success + validation paths)

### M4 — Traceability & Compliance Polish

- [ ] Lot expiry warnings in Plan + Batch consumption
- [ ] Printable batch sheet updates (signature, inputs/outputs summary)
- [ ] Lot→batch→orders and order→batch→lots reports (CSV/print)

## PDR — Plan Page

Scope & Navigation
- Location: `Production → Plan` (`/manage/production/plan`)
- Breadcrumbs: Production / Plan
- Roles: staff/admin full access; others read‑only

Pending Items (left)
- Query: `OrderItem` with `order.delivery_date <= today` and `remaining = quantity - completed_qty_sum > 0`
- Loads: `order.reference`, `order.customer.full_name`, aggregates, product name/sku
- Actions: multi-select checkboxes + “Add to Batch…”, and DragSelect/drag handles

Batches by Status (right)
- Lanes: To Do (open), In Progress, Done (completed)
- Cards: show `batch_code`, product, planned vs completed, quick actions that navigate to Batch Show

ASCII Wireframe

```
+----------------------------------------------------------------------------------+
| Production / Plan                                                   [Add to Batch]|
+----------------------------------------------------------------------------------+
| Filters: [Search…] [Product ▼] [Customer ▼] [Overdue only] [Reset]               |
+------------------------------+---------------------------------------------------+
| Pending Items                | Batches                                           |
| (Select or drag to batch)    | (By Status lanes)                                 |
|                              |                                                   |
| [ ] P: BREAD-001  #423  Doe   Qty 30  Rem 30  Alloc 0                            |
| [ ] P: BREAD-001  #424  Jane  Qty 10  Rem  5  Alloc 5                            |
| [ ] P: MUF-001    #425  Bob   Qty 24  Rem 24  Alloc 0                            |
| ...                          |  To Do                 In Progress        Done    |
| ⟲ Select N  [Add to Batch…]  |  + New Batch          [B-...-BREAD-001]  [B-... ]|
|                              |  [B-...-MUF-001]      [B-...-MUF-001]    [B-... ]|
+------------------------------+---------------------------------------------------+
```

Add to Batch Dialog
```
+---------------------------------------+
| Add 3 items to batch (Product: BREAD) |
+---------------------------------------+
| Target: (•) New batch   ( ) Existing  |
| Existing open batches:                |
|   [ B-...-BREAD-001 ]                 |
| Planned qty per item: defaults to remaining; editable        |
| [Cancel]                          [Add]                      |
+-------------------------------------------------------------+
```

Decisions & Assumptions
- Pending includes items with remaining > 0, regardless of current item.status, as long as `order.delivery_date <= today`
- Cross‑product selection allowed; “New batch” auto‑splits by product; “Existing” requires product match
- Batch code date uses today’s date for mixed‑past batching
- Default planned = remaining; user can edit in dialog
- Streams used for both lists to handle large N

Validation & Errors
- Product mismatch prevented on drop/selection; raise UI error
- Over‑allocation blocked by `AllocationWithinItemQuantity`; surface error messages per item
- Empty selection / no remaining → info flash, no action

Testing Plan
- LiveView: render pending, add to new batch (redirect), add to existing batch (chips update), DnD to batch, error flashes
- Batch actions: start/consume/complete happy paths + invalid lot plans

## Status Semantics

- Batch status (source of truth): `:open` → `:in_progress` → `:completed` (`:canceled` allowed)
- Item status (derived):
  - `:todo` if `completed_qty_sum == 0`
  - `:in_progress` if `0 < completed_qty_sum < item.quantity`
  - `:done` if `completed_qty_sum >= item.quantity`
- UI tags (derived only): “Allocated” if `planned_qty_sum > 0` and no completed; “Started” if included in an `:in_progress` batch

## Acceptance Criteria

- Operators can select pending items and create/add to batches (partial allowed) from the Plan page
- Batches appear in status lanes; start/consume/complete flows are available from batch detail
- Orders Items shows allocation chips; statuses are derived without manual editing
- Costs and lots allocate back to order items on completion
- LiveView tests cover Plan flows and Batch actions

## Risks & Notes

- BOM version drift: freeze a snapshot at batch `:open`; warn if items came from a different version
- Over/under production: support leftovers and unfulfilled allocations; warn visibly
- Performance: use aggregates + streams to keep reads and renders efficient
