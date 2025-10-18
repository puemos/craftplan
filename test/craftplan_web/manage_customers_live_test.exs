defmodule CraftplanWeb.ManageCustomersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CRM.Customer

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_customer!(attrs \\ %{}) do
    first = Map.get(attrs, :first_name, "Ada")
    last = Map.get(attrs, :last_name, "Lovelace")
    email = Map.get(attrs, :email, "ada+#{System.unique_integer()}@local")

    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: first,
      last_name: last,
      email: email,
      billing_address: %{street: "1 St", city: "X", country: "Y"},
      shipping_address: %{street: "1 St", city: "X", country: "Y"}
    })
    |> Ash.create!()
  end

  describe "index and new" do
    test "renders customers index for staff", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers")
      assert has_element?(view, "#customers")
    end

    test "renders new customer modal", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers/new")
      assert has_element?(view, "#customer-modal")
    end
  end

  describe "show tabs" do
    test "renders details tab for staff", %{conn: conn} do
      c = create_customer!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}")
      assert has_element?(view, "[role=tablist]")
      assert render(view) =~ c.first_name
    end

    test "renders orders and statistics tabs", %{conn: conn} do
      c = create_customer!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/orders")
      assert has_element?(view, "#customer_orders")

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/statistics")
      assert render(view) =~ "Total Orders"
    end

    test "renders edit modal for staff", %{conn: conn} do
      c = create_customer!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/edit")
      assert has_element?(view, "#customer-modal")
    end
  end
end
