defmodule CraftplanWeb.ManageCustomersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CRM.Customer

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
    @tag role: :staff
    test "renders customers index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/customers")
      assert has_element?(view, "#customers")
    end

    @tag role: :staff
    test "renders new customer button for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/customers")
      assert has_element?(view, "a[href='/manage/customers/new']")
    end

    @tag role: :staff
    test "renders new customer modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/customers/new")
      assert has_element?(view, "#customer-modal")
    end
  end

  describe "show tabs" do
    @tag role: :staff
    test "renders details tab for staff", %{conn: conn} do
      c = create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}")
      assert has_element?(view, "[role=tablist]")
      assert render(view) =~ c.first_name
    end

    @tag role: :staff
    test "renders details tab when billing_address is nil (imported customer)", %{conn: conn} do
      # Bottle-imported customers have a shipping_address but no billing_address.
      c =
        Customer
        |> Ash.Changeset.for_create(:create, %{
          type: :individual,
          first_name: "Imported",
          last_name: "Buyer",
          email: "imported+#{System.unique_integer([:positive])}@local",
          shipping_address: %{street: "1 St", city: "DC", country: "US"}
        })
        |> Ash.create!()

      assert is_nil(c.billing_address)

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}")
      assert render(view) =~ "Imported"
      assert render(view) =~ "Billing Address"
      assert render(view) =~ "Shipping Address"
    end

    @tag role: :staff
    test "renders orders and statistics tabs", %{conn: conn} do
      c = create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/orders")
      assert has_element?(view, "#customer_orders")

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/statistics")
      assert render(view) =~ "Total Orders"
    end

    @tag role: :staff
    test "renders edit modal for staff", %{conn: conn} do
      c = create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/customers/#{c.reference}/edit")
      assert has_element?(view, "#customer-modal")
    end
  end
end
