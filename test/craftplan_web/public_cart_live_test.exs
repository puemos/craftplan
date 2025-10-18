defmodule CraftplanWeb.PublicCartLiveTest do
  use CraftplanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Craftplan.Accounts.User
  alias Craftplan.Cart
  alias Craftplan.Catalog.Product

  defp staff_user! do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "staff+cart@ex.com",
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
      name: "Cart Prod",
      sku: "CART-" <> Base.encode16(:crypto.strong_rand_bytes(3), case: :lower),
      status: :active,
      price: Decimal.new("5.00")
    })
    |> Ash.create!(actor: staff)
  end

  test "cart shows item and allows quantity update", %{conn: conn} do
    # Create a cart and an item up-front
    {:ok, cart} = Cart.create_cart(%{items: []})
    product = create_product!()

    {:ok, item} =
      Cart.create_cart_item(%{
        cart_id: cart.id,
        product_id: product.id,
        quantity: 1,
        price: product.price
      })

    conn = init_test_session(conn, %{cart_id: cart.id})
    conn = Plug.Conn.assign(conn, :current_user, nil)
    item_id = item.id

    # Now open the cart page
    {:ok, view, _html} = live(conn, ~p"/cart", on_error: :warn)
    # Page renders
    assert render(view) =~ "Shopping Cart"

    # Find the update form and submit quantity change
    # (Component renders a single update form per item)
    _html_after =
      view
      |> element("#update-item-#{item_id}")
      |> render_submit(%{"item_id" => item_id, "quantity" => "3"})

    # Verify updated in data layer
    items = Cart.list_cart_items!(context: %{cart_id: cart.id})
    assert Enum.any?(items, fn it -> it.product_id == product.id and it.quantity == 3 end)
  end
end
