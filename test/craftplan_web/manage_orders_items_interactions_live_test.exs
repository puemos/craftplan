defmodule CraftplanWeb.ManageOrdersItemsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.{Product, Recipe}
  alias Craftplan.Inventory.Material
  alias Craftplan.Orders.Order

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

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
    |> Ash.create!(actor: staff_user!())
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
      |> Ash.create!(actor: staff_user!())

    _recipe =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        product_id: prod.id,
        components: [%{"material_id" => material.id, "quantity" => 1}]
      })
      |> Ash.create!()

    prod
  end

  defp create_order_with_item!(product) do
    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: Craftplan.CRM.Customer
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
    |> Ash.create!(actor: staff_user!())
  end

  test "items: mark done shows consume modal and confirm", %{conn: conn} do
    mat = create_material!()
    prod = create_product_with_recipe!(mat)
    order = create_order_with_item!(prod)

    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/orders/#{order.reference}/items")

    # Grab the item id from DB
    item = hd(order.items)

    # Change status to done
    view
    |> element("form[phx-change=update_item_status]")
    |> render_change(%{"item_id" => item.id, "status" => "done"})

    # Assert modal appears and confirm consumption
    assert has_element?(view, "#consume-confirm-modal")

    view
    |> element("#consume-confirm-modal button[phx-click=confirm_consume]")
    |> render_click()

    assert render(view) =~ "Materials consumed"
  end
end

