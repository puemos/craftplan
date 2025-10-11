defmodule Craftday.Orders.ConsumptionTest do
  use Craftday.DataCase, async: true

  alias Craftday.Catalog
  alias Craftday.CRM
  alias Craftday.Inventory
  alias Craftday.Orders
  alias Craftday.Orders.Consumption

  defp mk_material(name, sku, unit, price) do
    {:ok, mat} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price)
      })
      |> Ash.create()

    # seed initial stock 100
    {:ok, _} =
      Inventory.adjust_stock(%{material_id: mat.id, quantity: Decimal.new(100), reason: "seed"})

    mat
  end

  test "consumes materials when item marked done (idempotent)" do
    flour = mk_material("Flour", "F-1", :gram, "0.01")

    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Bread",
        status: :active,
        price: Decimal.new("5.00"),
        sku: "BREAD-1"
      })
      |> Ash.create()

    # Attach a recipe: 200g flour per piece
    {:ok, _recipe} =
      Catalog.Recipe
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        notes: ""
      })
      |> Ash.create()

    recipe = Catalog.get_product_by_id!(product.id, load: [:recipe]).recipe

    {:ok, _} =
      recipe
      |> Ash.Changeset.for_update(:update, %{
        components: [%{material_id: flour.id, quantity: Decimal.new(200)}]
      })
      |> Ash.update()

    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Test",
        last_name: "User"
      })
      |> Ash.create()

    {:ok, order} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        items: [
          %{product_id: product.id, quantity: Decimal.new(2), unit_price: Decimal.new("5.00")}
        ]
      })
      |> Ash.create()

    item = hd(order.items)

    # Mark done -> no consumption yet (semi-automatic)
    {:ok, item} = Orders.update_item(item, %{status: :done})
    flour = Ash.load!(Inventory.get_material_by_id!(flour.id), :current_stock)
    assert flour.current_stock == Decimal.new(100)

    # Explicitly consume
    {:ok, _} = Consumption.consume_item(item.id)
    flour = Ash.load!(Inventory.get_material_by_id!(flour.id), :current_stock)
    assert flour.current_stock == Decimal.new(-300)

    # Consume again -> idempotent
    {:ok, _} = Consumption.consume_item(item.id)
    flour = Ash.load!(Inventory.get_material_by_id!(flour.id), :current_stock)
    assert flour.current_stock == Decimal.new(-300)
  end
end
