defmodule CraftplanWeb.ManageOrdersInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CRM.Customer
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
      price: Decimal.new("4.50"),
      status: :active
    })
    |> Ash.create!(actor: staff_user!())
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

  test "orders index switch to calendar and today", %{conn: conn} do
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/orders")

    # Switch to calendar via tab link
    view
    |> element("a[href='/manage/orders?view=calendar']")
    |> render_click()

    assert_patch(view, ~p"/manage/orders?view=calendar")

    # Click today control
    view
    |> element("button[phx-click=today]")
    |> render_click()

    assert render(view)
  end

  test "create new order with one item", %{conn: conn} do
    product = create_product!()
    customer = create_customer!()

    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/orders/new")

    params = %{
      "order" => %{
        "customer_id" => customer.id,
        "delivery_date" => "2025-01-01T10:00",
        "items" => %{
          "0" => %{"product_id" => product.id, "quantity" => "2"}
        }
      },
      "timezone" => "Etc/UTC"
    }

    view
    |> element("#order-item-form")
    |> render_submit(params)

    assert render(view) =~ "Order saved successfully"
  end
end

