defmodule CraftplanWeb.ManageInventoryEditInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Material

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

  test "edit material and save", %{conn: conn} do
    m = create_material!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/edit")

    params = %{"material" => %{"name" => m.name <> "X"}}

    view
    |> element("#material-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.sku}/details")
    assert render(view) =~ "Material updated successfully"
  end
end
