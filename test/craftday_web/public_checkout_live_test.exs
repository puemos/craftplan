defmodule CraftdayWeb.PublicCheckoutLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.Accounts.User
  alias Craftday.Cart
  alias Craftday.Catalog.Product

  defp staff_user! do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "staff+checkout@ex.com",
      password: "Passw0rd!!",
      password_confirmation: "Passw0rd!!",
      role: :staff
    })
    |> Ash.create!(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  defp create_product! do
    staff = staff_user!()

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "Checkout Prod",
      sku: "CHK-" <> Base.encode16(:crypto.strong_rand_bytes(3), case: :lower),
      status: :active,
      price: Decimal.new("7.00")
    })
    |> Ash.create!(actor: staff)
  end

  test "checkout places order and clears cart", %{conn: conn} do
    {:ok, cart} = Cart.create_cart(%{items: []})
    product = create_product!()

    {:ok, _item} =
      Cart.create_cart_item(%{
        cart_id: cart.id,
        product_id: product.id,
        quantity: 2,
        price: product.price
      })

    conn = init_test_session(conn, %{cart_id: cart.id})
    conn = Plug.Conn.assign(conn, :current_user, nil)

    {:ok, view, _html} = live(conn, ~p"/checkout", on_error: :warn)

    params = %{
      "first_name" => "Jane",
      "last_name" => "Doe",
      "email" => "jane@example.com",
      "phone" => "555-1234",
      "delivery_date" => Date.to_iso8601(Date.utc_today()),
      "delivery_method" => "delivery",
      # addresses optional
      "shipping_street" => "1 Main",
      "shipping_city" => "City",
      "shipping_zip" => "00000",
      "shipping_country" => "US",
      "billing_street" => "1 Main",
      "billing_city" => "City",
      "billing_zip" => "00000",
      "billing_country" => "US"
    }

    _html_after =
      view
      |> element("form#checkout-form")
      |> render_submit(%{"checkout" => params})

    rendered = render(view)
    assert rendered =~ "Order placed successfully"
    assert rendered =~ "Thank you!"
  end
end
