defmodule CraftplanWeb.ManageOrdersDetailsEditInteractionsLiveTest do
  @moduledoc false

  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp create_customer! do
    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Ada",
      last_name: "Lovelace"
    })
    |> Ash.create!()
  end

  defp create_product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("3.50"),
      status: :active
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_order!(customer, product) do
    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: customer.id,
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => product.id, "quantity" => 1, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "edit order details and save", %{conn: conn} do
    c = create_customer!()
    p = create_product!()
    o = create_order!(c, p)

    {:ok, view, _} = live(conn, ~p"/manage/orders/#{o.reference}/edit")

    # No specific field required; submit minimal change (same customer)
    view
    |> element("#order-item-form")
    |> render_submit(%{"order" => %{}, "timezone" => "Etc/UTC"})

    assert_patch(view, ~p"/manage/orders/#{o.reference}")
    assert render(view) =~ "Order updated successfully"
  end
end
