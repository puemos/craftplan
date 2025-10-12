defmodule CraftdayWeb.ManageCustomersInteractionsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.CRM.Customer

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

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

  test "customer orders tab 'New Order' navigates to orders/new", %{conn: conn} do
    c = create_customer!()
    conn = sign_in(conn, staff_user!())

    {:ok, view, _} = live(conn, ~p"/manage/customers/#{c.reference}/orders")

    view
    |> element("a[href='/manage/orders/new?customer_id=#{c.reference}']")
    |> render_click()

    assert_redirect(view, ~p"/manage/orders/new?customer_id=#{c.reference}")
  end
end

