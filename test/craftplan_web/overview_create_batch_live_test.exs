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
  test "daily planner: create batch creates allocations and redirects", %{conn: conn} do
    mat = create_material!()
    prod = create_product_with_bom!(mat)
    order = create_order_with_items_for_today!(prod, [1, 2])

    {:ok, view, _} = live(conn, ~p"/manage/production/schedule?view=day")

    # Click Create Batch for this product/day
    view
    |> element("button[phx-click=create_batch][phx-value-product_id=\"#{prod.id}\"]")
    |> render_click(%{"date" => Date.to_iso8601(Date.utc_today()), "product_id" => prod.id})

    # Fetch the newly created batch and assert redirect was triggered to correct path
    {:ok, batch} =
      ProductionBatch
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(product_id == ^prod.id and status == :open))
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read_one(actor: Craftplan.DataCase.staff_actor())

    assert_redirect(view, ~p"/manage/production/batches/#{batch.batch_code}")

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

    {:ok, view, _} = live(conn, ~p"/manage/production/schedule?view=day")

    view
    |> element("button[phx-click=create_batch][phx-value-product_id=\"#{prod.id}\"]")
    |> render_click(%{"date" => Date.to_iso8601(Date.utc_today()), "product_id" => prod.id})

    assert render(view) =~ "Nothing remaining to allocate"
  end
end
