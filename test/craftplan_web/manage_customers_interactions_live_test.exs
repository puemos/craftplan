defmodule CraftplanWeb.ManageCustomersInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CRM.Customer

  defp create_customer! do
    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada+#{System.unique_integer()}@local"
    })
    |> Ash.create!()
  end

  @tag role: :staff
  test "customer orders tab 'New Order' navigates to orders/new", %{conn: conn} do
    c = create_customer!()

    {:ok, view, _} = live(conn, ~p"/manage/customers/#{c.reference}/orders")

    view
    |> element("a[href='/manage/orders/new?customer_id=#{c.reference}']")
    |> render_click()

    assert_redirect(view, ~p"/manage/orders/new?customer_id=#{c.reference}")
  end
end
