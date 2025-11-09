defmodule CraftplanWeb.ManageOrdersItemsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Orders.Order

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      price: Decimal.new("1.00"),
      unit: :gram,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_product_with_recipe!(material) do
    prod =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "P-#{System.unique_integer()}",
        sku: "SKU-#{System.unique_integer()}",
        price: Decimal.new("3.00"),
        status: :active
      })
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: prod.id,
        components: [
          %{"component_type" => :material, "material_id" => material.id, "quantity" => 1}
        ]
      })
      |> Ash.create!()

    prod
  end

  defp create_order_with_item!(product) do
    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id:
        Craftplan.CRM.Customer
        |> Ash.Changeset.for_create(:create, %{
          type: :individual,
          first_name: "Ada",
          last_name: "Lovelace"
        })
        |> Ash.create!()
        |> Map.fetch!(:id),
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => product.id, "quantity" => 1, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "items: add to batch shows allocation chip", %{conn: conn} do
    mat = create_material!()
    prod = create_product_with_recipe!(mat)
    order = create_order_with_item!(prod)

    # Create an open batch for the product
    {:ok, batch} =
      Craftplan.Orders.ProductionBatch
      |> Ash.Changeset.for_create(:open, %{product_id: prod.id, planned_qty: Decimal.new("0")})
      |> Ash.create(actor: Craftplan.DataCase.staff_actor())

    {:ok, view, _} = live(conn, ~p"/manage/orders/#{order.reference}/items")

    # Grab the item id from DB
    item = hd(order.items)

    # Open the Add to Batch modal
    view
    |> element("button[phx-click=open_add_to_batch][phx-value-item_id=\"#{item.id}\"]")
    |> render_click()

    # Submit allocation to the batch
    view
    |> form("#add-to-batch-form", %{batch_id: batch.id, planned_qty: "1"})
    |> render_submit()

    # Verify allocations chip updated
    assert render(view) =~ "Allocations"
    assert render(view) =~ "Planned: 1"
  end
end
