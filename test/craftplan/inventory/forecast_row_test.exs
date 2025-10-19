defmodule Craftplan.Inventory.ForecastRowTest do
  use ExUnit.Case, async: true

  alias Craftplan.Inventory.ForecastMetrics
  alias Craftplan.Inventory.ForecastRow
  alias Decimal, as: D

  test "owner_grid_metrics manual action computes metrics for provided rows" do
    today = ~D[2025-02-15]
    projections = [
      %{date: today, balance: 50},
      %{date: Date.add(today, 1), balance: 35},
      %{date: Date.add(today, 2), balance: -5}
    ]

    actual_usage = [10, 12, 8, 11, 9, 10]
    planned_usage = [12, 11, 9, 10]
    on_hand = 50
    on_order = 20
    lead_time_days = 5
    service_level_z = 1.65
    pack_size = 25
    max_cover_days = 10

    rows = [
      %{
        material_id: Ash.UUID.generate(),
        material_name: "Flour",
        on_hand: on_hand,
        on_order: on_order,
        lead_time_days: lead_time_days,
        service_level_z: service_level_z,
        pack_size: pack_size,
        max_cover_days: max_cover_days,
        actual_usage: actual_usage,
        planned_usage: planned_usage,
        projected_balances: projections
      }
    ]

    expected_avg = ForecastMetrics.avg_daily_use(actual_usage, planned_usage)
    expected_variability = ForecastMetrics.demand_variability(actual_usage, planned_usage)
    expected_lead_time_demand = ForecastMetrics.lead_time_demand(expected_avg, lead_time_days)
    expected_safety_stock =
      ForecastMetrics.safety_stock(
        D.from_float(service_level_z),
        expected_variability,
        lead_time_days
      )

    expected_reorder_point = ForecastMetrics.reorder_point(expected_lead_time_demand, expected_safety_stock)
    expected_cover = ForecastMetrics.cover_days(on_hand, expected_avg)
    expected_stockout = ForecastMetrics.stockout_date(Enum.map(projections, &{&1.date, &1.balance}))
    expected_order_by = ForecastMetrics.order_by_date(expected_stockout, lead_time_days)

    expected_suggested =
      ForecastMetrics.suggested_po_qty(
        expected_reorder_point,
        on_hand,
        on_order,
        pack_size: pack_size,
        avg_daily_use: expected_avg,
        max_cover_days: max_cover_days
      )

    expected_risk = ForecastMetrics.risk_state(Enum.map(projections, &{&1.date, &1.balance}))

    result =
      ForecastRow
      |> Ash.Query.for_read(:owner_grid_metrics, %{rows: rows})
      |> Ash.read!()

    assert [%{material_name: "Flour"} = row] = result

    assert Decimal.compare(row.avg_daily_use, expected_avg) == :eq
    assert Decimal.compare(row.demand_variability, expected_variability) == :eq
    assert Decimal.compare(row.lead_time_demand, expected_lead_time_demand) == :eq
    assert Decimal.compare(row.safety_stock, expected_safety_stock) == :eq
    assert Decimal.compare(row.reorder_point, expected_reorder_point) == :eq
    assert cover_equals?(row.cover_days, expected_cover)
    assert row.stockout_date == expected_stockout
    assert row.order_by_date == expected_order_by
    assert Decimal.compare(row.suggested_po_qty, expected_suggested) == :eq
    assert row.risk_state == expected_risk
    assert Enum.count(row.projected_balances) == length(projections)
  end

  defp cover_equals?(nil, nil), do: true
  defp cover_equals?(%Decimal{} = left, %Decimal{} = right),
    do: Decimal.compare(left, right) == :eq
  defp cover_equals?(_, _), do: false
end

