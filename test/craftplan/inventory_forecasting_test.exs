defmodule Craftplan.InventoryForecastingTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog.Product
  alias Craftplan.Catalog.Recipe
  alias Craftplan.Inventory.ForecastMetrics
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.Movement
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders

  defp material!(name) do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: name <> "-SKU",
      price: Decimal.new("1.00"),
      unit: :gram,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp product_with_recipe!(m1, m2) do
    p =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Prod-#{System.unique_integer()}",
        sku: "SKU-#{System.unique_integer()}",
        price: Decimal.new("3.00"),
        status: :active
      })
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    _recipe =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        components: [
          %{"material_id" => m1.id, "quantity" => 2},
          %{"material_id" => m2.id, "quantity" => 1}
        ]
      })
      |> Ash.create!()

    p
  end

  defp order!(product, dt, qty) do
    customer =
      Craftplan.CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Cust",
        last_name: "One"
      })
      |> Ash.create!()

    Orders.Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: customer.id,
      delivery_date: dt,
      items: [%{"product_id" => product.id, "quantity" => qty, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp stock!(material, quantity) do
    Movement
    |> Ash.Changeset.for_create(:adjust_stock, %{
      material_id: material.id,
      quantity: Decimal.new(quantity),
      reason: "initial stock"
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp ensure_settings! do
    Craftplan.Settings.init()
  rescue
    _ -> :ok
  end

  test "prepare_materials_requirements aggregates by day and material" do
    m1 = material!("Flour")
    m2 = material!("Sugar")
    p = product_with_recipe!(m1, m2)

    today = Date.utc_today()
    dt1 = DateTime.new!(today, ~T[10:00:00], "Etc/UTC")
    dt2 = DateTime.new!(Date.add(today, 1), ~T[11:00:00], "Etc/UTC")

    _o1 = order!(p, dt1, 1)
    _o2 = order!(p, dt2, 3)

    days_range = [today, Date.add(today, 1)]

    reqs =
      InventoryForecasting.prepare_materials_requirements(
        days_range,
        Craftplan.DataCase.staff_actor()
      )

    # Expect two materials
    assert length(reqs) == 2

    {flour, flour_data} = Enum.find(reqs, fn {mat, _} -> mat.name == "Flour" end)
    assert flour.name == "Flour"
    # quantities per day: day1 2*1=2, day2 2*3=6
    assert flour_data.quantities |> Enum.at(0) |> elem(0) == Decimal.new(2)
    assert flour_data.quantities |> Enum.at(1) |> elem(0) == Decimal.new(6)
    # total = 8
    assert flour_data.total_quantity == Decimal.new(8)
  end

  test "owner_grid_rows builds forecast rows with blended metrics" do
    ensure_settings!()

    m1 = material!("Flour")
    m2 = material!("Sugar")
    stock!(m1, 50)
    stock!(m2, 50)

    product = product_with_recipe!(m1, m2)

    today = Date.utc_today()
    tz = "Etc/UTC"

    # Past five days of consumption (actual usage)
    Enum.each(1..5, fn days_ago ->
      dt = DateTime.new!(Date.add(today, -days_ago), ~T[09:00:00], tz)
      order!(product, dt, 1)
    end)

    future_quantities = [1, 2, 3]

    days_range =
      future_quantities
      |> Enum.with_index()
      |> Enum.map(fn {_qty, idx} -> Date.add(today, idx) end)

    Enum.zip(future_quantities, days_range)
    |> Enum.each(fn {qty, day} ->
      dt = DateTime.new!(day, ~T[10:00:00], tz)
      order!(product, dt, qty)
    end)

    staff = Craftplan.DataCase.staff_actor()

    rows =
      InventoryForecasting.owner_grid_rows(
        days_range,
        [service_level: 0.95, lookback_days: 5],
        staff
      )

    flour_row =
      Enum.find(rows, fn row -> row.material_name == m1.name end)

    assert flour_row
    assert Decimal.compare(flour_row.on_hand, Decimal.new("50")) == :eq
    assert Decimal.compare(flour_row.on_order, Decimal.new("0")) == :eq
    assert flour_row.lead_time_days == 0
    assert Decimal.equal?(flour_row.service_level_z, Decimal.from_float(1.65))
    assert Enum.count(flour_row.projected_balances) == length(days_range)

    actual_samples = Enum.map(1..5, fn _ -> Decimal.new(2) end)
    planned_samples = Enum.map(future_quantities, fn qty -> Decimal.new(qty * 2) end)

    expected_avg = ForecastMetrics.avg_daily_use(actual_samples, planned_samples)
    expected_variability = ForecastMetrics.demand_variability(actual_samples, planned_samples)
    expected_cover = ForecastMetrics.cover_days(Decimal.new("50"), expected_avg)

    assert Decimal.compare(flour_row.avg_daily_use, expected_avg) == :eq
    assert Decimal.compare(flour_row.demand_variability, expected_variability) == :eq
    assert Decimal.compare(flour_row.lead_time_demand, Decimal.new("0")) == :eq
    assert Decimal.compare(flour_row.safety_stock, Decimal.new("0")) == :eq
    assert Decimal.compare(flour_row.reorder_point, Decimal.new("0")) == :eq
    assert cover_equals?(flour_row.cover_days, expected_cover)
    assert flour_row.stockout_date == nil
    assert flour_row.order_by_date == nil
    assert Decimal.compare(flour_row.suggested_po_qty, Decimal.new("0")) == :eq
    assert flour_row.risk_state == :balanced

    expected_balances = [48, 44, 38]

    actual_balances =
      Enum.map(flour_row.projected_balances, fn %{balance: balance} -> balance end)

    Enum.zip(actual_balances, Enum.map(expected_balances, &Decimal.new/1))
    |> Enum.each(fn {actual, expected} ->
      assert Decimal.compare(actual, expected) == :eq
    end)
  end

  defp cover_equals?(nil, nil), do: true
  defp cover_equals?(%Decimal{} = left, %Decimal{} = right),
    do: Decimal.compare(left, right) == :eq
  defp cover_equals?(_, _), do: false
end
