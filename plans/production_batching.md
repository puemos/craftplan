# Production Batching Subplan

Last updated: 2025-11-09

## Objective

Move Craftplan to true batch‑centric production so operators can plan, consume, and complete one run for many order items — with costs and lots allocated back to each item and batch-aware planning across the UI.

## Milestones

### M1 — Domain & Actions (Batch Core)

- [ ] Add `Orders.OrderItemBatchAllocation` resource (join: batch ↔ order item) with validations
- [ ] Extend `Orders.ProductionBatch` with snapshot + planning fields (status, planned/produced/scrap, notes; BOM snapshot)
- [ ] Add batch actions: `:open`, `:start`, `:consume`, `:complete`
- [ ] Tag inventory movements with `production_batch_id` or add `ProductionBatchLot` for traceability
- [ ] Allocation service: distribute batch costs/finished‑lot to items by completed_qty
- [ ] Aggregates on `OrderItem`: `planned_qty_sum`, `completed_qty_sum`
- [ ] Tests: allocation math, status derivation, cost rounding

### M1.5 — Resource Actions & Validations (Ash-first)

- [x] `ProductionBatch` actions:
  - [x] `create :open` → freeze BOM snapshot, generate `batch_code`, set status `:open`
  - [x] `create :open_with_allocations` → manage `allocations` in one call (uses `manage_relationship`)
  - [x] `update :start` → status `:in_progress`, set `started_at`
  - [x] `update :consume` → accepts `lot_plan` and delegates to service/flow; change surfaces errors
  - [x] `update :complete` → accepts `produced_qty`, etc.; change sets fields and surfaces errors via after_action
- [x] `ProductionBatch` read actions:
  - [x] `read :recent` (paged, newest first, minimal loads)
  - [x] `read :detail` (loads product, bom snapshot, allocations→order items, lots)
- [x] `OrderItemBatchAllocation` validations:
  - [x] Product match with batch product
  - [x] Non‑negative quantities; `completed_qty <= planned_qty`
  - [x] Guard rails for over‑allocation (sum vs remaining); validation prevents planned total > item.quantity
- [ ] Deprecate per‑item `Orders.Consumption`; add `OrderItem.action :quick_complete` that runs an auto‑batch path (follow‑up)

### M2 — UI Wiring (Planner, Orders, Batches)

- [ ] Planner (Schedule): “Create Batch” from product/day; suggest pending items; list open/in‑progress/completed batches
- [ ] Orders → Items: allocation chips + “Add to Batch…” action; read‑only derived status
- [ ] Batch detail: Items, Consumption (lots), Completion (costing + allocation), Print
- [ ] Make Sheet → Batch Sheet for the day (lists batches + items)
- [ ] Tests: LiveView flows for create/add/start/consume/complete

### M3 — Traceability & Compliance Polish

- [ ] Lot expiry warnings in Planner + Batch consumption
- [ ] Printable batch sheet updates (signature, inputs/outputs summary)
- [ ] Lot→batch→orders and order→batch→lots reports (CSV/print)

### M4 — Kanban Planning

- [ ] Kanban view: Unallocated → Open → In Progress → Completed, by product
- [ ] Drag‑to‑allocate items to batches; drag batch across columns to trigger actions
- [ ] Tests for Kanban hooks + state transitions

## Status Semantics

- Batch status (source of truth): `:open` → `:in_progress` → `:completed` (`:canceled` allowed)
- Item status (derived):
  - `:todo` if `completed_qty_sum == 0`
  - `:in_progress` if `0 < completed_qty_sum < item.quantity`
  - `:done` if `completed_qty_sum >= item.quantity`
- UI tags (derived only): “Allocated” if `planned_qty_sum > 0` and no completed; “Started” if included in an `:in_progress` batch

## Acceptance Criteria

- Operators can create a batch, add many order items (partial allowed), consume lots once, and complete the batch once
- Costs and finished goods lot are allocated back to each order item; item status updates automatically
- Planner surfaces batches and replaces per‑item “complete” with batch actions; Orders shows allocation chips and batch links
- Traceability reports list all lots used and affected orders within seconds

## Risks & Notes

- BOM version drift: freeze a snapshot at batch `:open`; warn if items came from a different version
- Over/under production: support leftover finished goods or unfulfilled allocations; warn visibly
- Performance: rely on persisted `components_map` for material needs; use Ash aggregates to keep reads O(1)
