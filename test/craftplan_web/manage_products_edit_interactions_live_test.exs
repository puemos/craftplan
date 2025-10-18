defmodule CraftplanWeb.ManageProductsEditInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("4.00"),
      status: :active
    })
    |> Ash.create!(actor: staff_user!())
  end

  test "edit product name and save", %{conn: conn} do
    p = create_product!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/products/#{p.sku}/edit")

    params = %{"product" => %{"name" => p.name <> "X"}}

    view
    |> element("#product-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/products/#{p.sku}/details")
    assert render(view) =~ "Product updated successfully"
  end
end
