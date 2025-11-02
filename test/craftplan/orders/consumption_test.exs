defmodule Craftplan.Orders.ConsumptionTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog
  alias Craftplan.CRM
  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias Craftplan.Orders.Consumption

  defp mk_material(name, sku, unit, price) do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, mat} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price)
      })
      |> Ash.create(actor: actor)

    # seed initial stock 100
    {:ok, _} =
      Inventory.adjust_stock(%{material_id: mat.id, quantity: Decimal.new(100), reason: "seed"},
        actor: actor
      )

    mat
  end

  test "consumes materials when item marked done (idempotent)" do
    actor = Craftplan.DataCase.staff_actor()
    flour = mk_material("Flour", "F-1", :gram, "0.01")

    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Bread",
        status: :active,
        price: Decimal.new("5.00"),
        sku: "BREAD-1"
      })
      |> Ash.create(actor: actor)

    # Attach a BOM: 200g flour per piece
    {:ok, _bom} =
      Catalog.BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        status: :active,
        components: [
          %{component_type: :material, material_id: flour.id, quantity: Decimal.new(200)}
        ]
      })
      |> Ash.create(actor: actor)

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
      |> Ash.create(actor: actor)

    item = hd(order.items)

    # Mark done -> no consumption yet (semi-automatic)
    {:ok, item} = Orders.update_item(item, %{status: :done}, actor: actor)

    flour =
      Ash.load!(Inventory.get_material_by_id!(flour.id, actor: actor), :current_stock, actor: actor)

    assert flour.current_stock == Decimal.new(100)

    # Explicitly consume
    {:ok, _} = Consumption.consume_item(item.id, actor: actor)

    flour =
      Ash.load!(Inventory.get_material_by_id!(flour.id, actor: actor), :current_stock, actor: actor)

    assert flour.current_stock == Decimal.new(-300)

    # Consume again -> idempotent
    {:ok, _} = Consumption.consume_item(item.id, actor: actor)

    flour =
      Ash.load!(Inventory.get_material_by_id!(flour.id, actor: actor), :current_stock, actor: actor)

    assert flour.current_stock == Decimal.new(-300)
  end
end
