defmodule Craftplan.Inventory.ForecastMetricsTest do
  use ExUnit.Case, async: true

  alias Craftplan.Inventory.ForecastMetrics
  alias Decimal, as: D

  describe "avg_daily_use/3" do
    test "blends actual and planned usage with default weights" do
      actual = [10, 12, 8, 11, 9, 10]
      planned = [12, 11, 9, 10]

      result = ForecastMetrics.avg_daily_use(actual, planned)

      assert_decimal_close(result, 10.2)
    end

    test "falls back to actuals when planned usage is missing" do
      actual = [15, 14, 16, 15]

      result = ForecastMetrics.avg_daily_use(actual, [])

      assert_decimal_close(result, 15.0)
    end
  end

  describe "demand_variability/3" do
    test "uses half of average when sample size is below threshold" do
      actual = [10, 12, 8]
      planned = [11]

      result = ForecastMetrics.demand_variability(actual, planned)

      assert_decimal_close(result, 5.2)
    end

    test "computes population standard deviation when enough samples" do
      actual = [10, 12, 9, 11, 10, 13, 12, 9, 11, 10]
      planned = []

      result = ForecastMetrics.demand_variability(actual, planned)

      assert_decimal_close(result, 1.268857754)
    end
  end

  describe "lead_time and safety stock calculations" do
    test "derives lead time demand from average usage" do
      avg_use = D.from_float(10.2)

      result = ForecastMetrics.lead_time_demand(avg_use, 7)

      assert_decimal_close(result, 71.4)
    end

    test "computes safety stock with z, variability, and lead time" do
      z = D.from_float(1.65)
      variability = D.from_float(5.0)

      result = ForecastMetrics.safety_stock(z, variability, 4)

      assert_decimal_close(result, 16.5)
    end

    test "reorder point combines lead time demand and safety stock" do
      lead_time_demand = D.from_float(71.4)
      safety_stock = D.from_float(16.5)

      result = ForecastMetrics.reorder_point(lead_time_demand, safety_stock)

      assert_decimal_close(result, 87.9)
    end
  end

  describe "cover_days/2" do
    test "returns nil when average usage is zero" do
      assert ForecastMetrics.cover_days(100, 0) == nil
    end

    test "returns decimal cover when average usage is positive" do
      result = ForecastMetrics.cover_days(50, D.from_float(10.2))

      assert_decimal_close(result, 4.90196078)
    end
  end

  describe "stockout and order-by dates" do
    test "identifies first negative projected balance" do
      today = ~D[2025-02-15]
      projections = [
        {today, 12},
        {Date.add(today, 1), 4},
        {Date.add(today, 2), -3},
        {Date.add(today, 3), -5}
      ]

      assert ForecastMetrics.stockout_date(projections) == Date.add(today, 2)
    end

    test "returns nil when there is no stockout" do
      today = ~D[2025-02-15]
      projections = [
        {today, 12},
        {Date.add(today, 1), 8}
      ]

      assert ForecastMetrics.stockout_date(projections) == nil
    end

    test "subtracts rounded lead time to get order-by date" do
      stockout = ~D[2025-03-10]

      assert ForecastMetrics.order_by_date(stockout, 3.2) == ~D[2025-03-06]
    end
  end

  describe "suggested_po_qty/4" do
    test "rounds up to the nearest pack size" do
      reorder_point = D.from_float(120.0)
      on_hand = 40
      on_order = 20

      result =
        ForecastMetrics.suggested_po_qty(
          reorder_point,
          on_hand,
          on_order,
          pack_size: 25
        )

      assert_decimal_close(result, 75.0)
    end

    test "applies max cover days cap when provided" do
      reorder_point = D.from_float(120.0)
      on_hand = 40
      on_order = 20

      result =
        ForecastMetrics.suggested_po_qty(
          reorder_point,
          on_hand,
          on_order,
          pack_size: 25,
          avg_daily_use: D.from_float(10.0),
          max_cover_days: 10
        )

      assert_decimal_close(result, 50.0)
    end
  end

  describe "risk_state/1" do
    test "returns :shortage when any balance drops below zero" do
      today = ~D[2025-02-15]
      projections = [{today, 5}, {Date.add(today, 1), -1}]

      assert ForecastMetrics.risk_state(projections) == :shortage
    end

    test "returns :watch when balances hit exactly zero" do
      today = ~D[2025-02-15]
      projections = [{today, 5}, {Date.add(today, 1), 0}, {Date.add(today, 2), 3}]

      assert ForecastMetrics.risk_state(projections) == :watch
    end

    test "returns :balanced when balances stay positive" do
      today = ~D[2025-02-15]
      projections = [{today, 5}, {Date.add(today, 1), 3}, {Date.add(today, 2), 1}]

      assert ForecastMetrics.risk_state(projections) == :balanced
    end
  end

  defp assert_decimal_close(actual, expected_float, delta \\ 1.0e-6) do
    actual_float = D.to_float(actual)
    assert_in_delta(actual_float, expected_float, delta)
  end
end
