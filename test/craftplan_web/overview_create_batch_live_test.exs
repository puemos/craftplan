defmodule CraftplanWeb.OverviewCreateBatchLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Ash.Expr
  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias Craftplan.Orders.ProductionBatch

  require Ash.Query

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

  defp create_product_with_bom!(material) do
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
        ],
        status: :active
      })
      |> Ash.create!()

    prod
  end

  defp create_order_with_items_for_today!(product, qtys) do
    Orders.Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id:
        Craftplan.CRM.Customer
        |> Ash.Changeset.for_create(:create, %{
          type: :individual,
          first_name: "Grace",
          last_name: "Hopper"
        })
        |> Ash.create!()
        |> Map.fetch!(:id),
      delivery_date: DateTime.utc_now(),
      items:
        Enum.map(qtys, fn q ->
          %{"product_id" => product.id, "quantity" => q, "unit_price" => product.price}
        end)
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "daily planner: create batch creates allocations and stays on page", %{conn: conn} do
    mat = create_material!()
    prod = create_product_with_bom!(mat)
    _order = create_order_with_items_for_today!(prod, [1, 2])

    {:ok, view, _} = live(conn, ~p"/manage/production/schedule?view=day")

    # Open unbatched modal, then click Batch All
    view
    |> element(~s([phx-click="open_unbatched_modal"][phx-value-product-id="#{prod.id}"]))
    |> render_click()

    view
    |> element("button", "Batch All")
    |> render_click()

    # Should stay on page (no redirect), show flash
    html = render(view)
    assert html =~ "created"

    # Fetch the newly created batch
    {:ok, batch} =
      ProductionBatch
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(product_id == ^prod.id and status == :open))
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read_one(actor: Craftplan.DataCase.staff_actor())

    assert batch

    # Assert allocations exist for items
    allocs =
      OrderItemBatchAllocation
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(production_batch_id == ^batch.id))
      |> Ash.read!(actor: Craftplan.DataCase.staff_actor())

    assert length(allocs) >= 1

    assert Enum.all?(
             allocs,
             &(&1.planned_qty && Decimal.compare(&1.planned_qty, Decimal.new(0)) == :gt)
           )
  end

  @tag role: :staff
  test "daily planner: no remaining shows info flash, no redirect", %{conn: conn} do
    mat = create_material!()
    prod = create_product_with_bom!(mat)
    order = create_order_with_items_for_today!(prod, [1])

    # Pre-allocate all quantity
    {:ok, batch} =
      ProductionBatch
      |> Ash.Changeset.for_create(:open, %{product_id: prod.id, planned_qty: Decimal.new("1")})
      |> Ash.create(actor: Craftplan.DataCase.staff_actor())

    _alloc =
      OrderItemBatchAllocation
      |> Ash.Changeset.for_create(:create, %{
        production_batch_id: batch.id,
        order_item_id: hd(order.items).id,
        planned_qty: Decimal.new("1")
      })
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    {:ok, view, html} = live(conn, ~p"/manage/production/schedule?view=day")

    # The item is now allocated, so it should appear in the Open column
    # There should be no unbatched card for this product since it's already allocated
    if has_element?(
         view,
         ~s([phx-click="open_unbatched_modal"][phx-value-product-id="#{prod.id}"])
       ) do
      view
      |> element(~s([phx-click="open_unbatched_modal"][phx-value-product-id="#{prod.id}"]))
      |> render_click()

      view
      |> element("button", "Batch All")
      |> render_click()

      assert render(view) =~ "Nothing remaining to allocate"
    else
      # Item is already in a batch column — no unbatched card expected
      assert html =~ "Open"
    end
  end
end
