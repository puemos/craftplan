defmodule CraftplanWeb.ProductionPlanLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Ash.Expr
  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  require Ash.Query

  defp create_product_with_bom! do
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
        components: [],
        status: :active
      })
      |> Ash.create!()

    prod
  end

  defp create_order_with_item!(product, qty, days_offset \\ 0) do
    %Customer{id: customer_id} =
      Customer
      |> Ash.Changeset.for_create(:create, %{type: :individual, first_name: "T", last_name: "U"})
      |> Ash.create!()

    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: customer_id,
      delivery_date: DateTime.add(DateTime.utc_now(), days_offset, :day),
      items: [%{"product_id" => product.id, "quantity" => qty, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "renders pending and creates batch from selection", %{conn: conn} do
    prod = create_product_with_bom!()
    order = create_order_with_item!(prod, 3)
    item = hd(order.items)

    {:ok, view, _} = live(conn, ~p"/manage/production/plan")

    view
    |> element("#pending-items input[type=checkbox][value=\"#{item.id}\"]")
    |> render_click()

    view
    |> element("#batch-button")
    |> render_click()

    view
    |> form(
      "#plan-batch-form",
      %{
        "product_ids[0]" => prod.id,
        "targets" => %{prod.id => "new"}
      }
    )
    |> render_submit()

    {:ok, batch} =
      Craftplan.Orders.ProductionBatch
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(product_id == ^prod.id and status == :open))
      |> Ash.read_one(actor: Craftplan.DataCase.staff_actor())

    assert batch
    assert render(view) =~ "Created/updated batches"
  end
end
