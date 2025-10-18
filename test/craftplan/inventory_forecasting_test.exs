defmodule Craftplan.InventoryForecastingTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.InventoryForecasting
  alias Craftplan.Inventory.Material
  alias Craftplan.Catalog.{Product, Recipe}
  alias Craftplan.Orders

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

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
    |> Ash.create!(actor: staff_user!())
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
      |> Ash.create!(actor: staff_user!())

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
    |> Ash.create!(actor: staff_user!())
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
    reqs = InventoryForecasting.prepare_materials_requirements(days_range, staff_user!())

    # Expect two materials
    assert length(reqs) == 2

    {flour, flour_data} = Enum.find(reqs, fn {mat, _} -> mat.name == "Flour" end)
    assert flour.name == "Flour"
    # quantities per day: day1 2*1=2, day2 2*3=6
    assert Enum.at(flour_data.quantities, 0) |> elem(0) == Decimal.new(2)
    assert Enum.at(flour_data.quantities, 1) |> elem(0) == Decimal.new(6)
    # total = 8
    assert flour_data.total_quantity == Decimal.new(8)
  end
end
