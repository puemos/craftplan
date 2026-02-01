// Production Batch Sheet — Craftplan
// Data is passed via sys.inputs.elixir_data

#let data = sys.inputs.elixir_data

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2.5cm, left: 2cm, right: 2cm),
  footer: context {
    set text(8pt, fill: luma(120))
    grid(
      columns: (1fr, 1fr),
      align(left, [Batch #data.batch_code]),
      align(right, [Page #counter(page).display("1 of 1", both: true)]),
    )
  },
)

#set text(font: "Inter", size: 10pt)

// ── Header ──────────────────────────────────────────────────
#align(center)[
  #text(18pt, weight: "bold")[Production Batch Sheet]
]

#v(0.5cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 0.5cm,
  [
    #text(14pt, weight: "bold")[#data.batch_code] \
    #text(11pt)[#data.product_name] \
    #text(9pt, fill: luma(100))[SKU: #data.product_sku]
  ],
  align(right)[
    #text(11pt)[Status: *#data.status*] \
    #text(10pt)[Planned Qty: *#data.planned_qty*] \
    #if data.produced_at != "" [
      #text(9pt, fill: luma(100))[Produced: #data.produced_at]
    ]
  ],
)

#line(length: 100%, stroke: 0.5pt + luma(180))

// ── Orders ──────────────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Orders]
#v(0.2cm)

#if data.orders.len() > 0 [
  #table(
    columns: (auto, 1fr, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, left, right, left),
    table.header(
      [*Reference*], [*Customer*], [*Quantity*], [*Delivery Date*],
    ),
    ..for order in data.orders {
      (
        order.reference,
        order.customer_name,
        order.quantity,
        order.delivery_date,
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No orders allocated to this batch.]
]

// ── Materials / BOM ─────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Materials (Bill of Materials)]
#v(0.2cm)

#if data.bom_components.len() > 0 [
  #table(
    columns: (1fr, auto, auto, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, right, right, left, right, right),
    table.header(
      [*Material*], [*Qty / Unit*], [*Total Req.*], [*Unit*], [*Waste %*], [*Actual Used*],
    ),
    ..for comp in data.bom_components {
      (
        comp.name,
        comp.qty_per_unit,
        comp.total_required,
        comp.unit,
        comp.waste_percent,
        [],
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No BOM components found.]
]

// ── Labor Steps ─────────────────────────────────────────────
#v(0.4cm)
#text(12pt, weight: "bold")[Labor Steps]
#v(0.2cm)

#if data.labor_steps.len() > 0 [
  #table(
    columns: (auto, 1fr, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (center, left, right, right, center),
    table.header(
      [*\#*], [*Step*], [*Duration (min)*], [*Units / Run*], [*Done*],
    ),
    ..for step in data.labor_steps {
      (
        step.sequence,
        step.name,
        step.duration_minutes,
        step.units_per_run,
        [$square$],
      )
    },
  )
] else [
  #text(9pt, fill: luma(120))[No labor steps defined.]
]

// ── Lots Consumed (conditional) ─────────────────────────────
#if data.lots.len() > 0 [
  #v(0.4cm)
  #text(12pt, weight: "bold")[Lots Consumed]
  #v(0.2cm)

  #table(
    columns: (auto, 1fr, auto, auto, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, left, right, left, left),
    table.header(
      [*Lot Code*], [*Material*], [*Qty Used*], [*Expiry*], [*Supplier*],
    ),
    ..for lot in data.lots {
      (
        lot.lot_code,
        lot.material_name,
        lot.quantity_used,
        lot.expiry_date,
        lot.supplier,
      )
    },
  )
]

// ── Cost Summary (conditional — only if batch completed) ────
#if data.show_costs == "yes" [
  #v(0.4cm)
  #text(12pt, weight: "bold")[Cost Summary]
  #v(0.2cm)

  #table(
    columns: (1fr, auto),
    stroke: 0.4pt + luma(180),
    inset: 6pt,
    align: (left, right),
    [Material Cost], [#data.costs.material_cost],
    [Labor Cost], [#data.costs.labor_cost],
    [Overhead Cost], [#data.costs.overhead_cost],
    table.hline(stroke: 1pt),
    [*Total Cost*], [*#data.costs.total_cost*],
    [*Unit Cost*], [*#data.costs.unit_cost*],
  )
]

// ── Compliance Footer ───────────────────────────────────────
#v(1cm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(0.3cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(9pt, weight: "bold")[Operator] \
    #v(0.8cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
    #text(8pt, fill: luma(120))[Signature]
  ],
  [
    #text(9pt, weight: "bold")[Supervisor] \
    #v(0.8cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
    #text(8pt, fill: luma(120))[Signature]
  ],
)

#v(0.3cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(9pt, weight: "bold")[Date] \
    #v(0.5cm)
    #line(length: 100%, stroke: 0.4pt + luma(150))
  ],
  [],
)

#v(0.3cm)
#text(9pt, weight: "bold")[Observations]
#v(0.2cm)
#rect(
  width: 100%,
  height: 3cm,
  stroke: 0.4pt + luma(150),
  radius: 2pt,
  inset: 8pt,
  text(9pt, fill: luma(140))[#data.observations],
)
