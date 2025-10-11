defmodule CraftdayWeb.Public.CheckoutLive.Index do
  @moduledoc false
  use CraftdayWeb, :live_view

  alias Craftday.Cart
  alias Craftday.CRM
  alias Craftday.CRM.Customer
  alias Craftday.Orders

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Cart" path={~p"/cart"} current?={false} />
        <:crumb label="Checkout" path={~p"/checkout"} current?={true} />
      </.breadcrumb>
    </.header>

    <div :if={@order_reference} class="rounded border border-stone-200 bg-white p-6">
      <h2 class="mb-2 text-xl font-semibold">Thank you!</h2>
      <p class="text-stone-700">
        Your order has been placed. Reference:
        <.kbd>{@order_reference}</.kbd>
      </p>
      <div class="mt-4">
        <.link navigate={~p"/catalog"}>
          <.button>Continue Shopping</.button>
        </.link>
      </div>
    </div>

    <div :if={!@order_reference} class="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div class="lg:col-span-2">
        <.simple_form for={@form} id="checkout-form" phx-change="validate" phx-submit="place_order">
          <h3 class="mb-2 text-lg font-medium">Customer</h3>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input field={@form[:first_name]} type="text" label="First name" />
            <.input field={@form[:last_name]} type="text" label="Last name" />
          </div>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:phone]} type="text" label="Phone" />
          </div>

          <h3 class="mt-6 mb-2 text-lg font-medium">Delivery</h3>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input field={@form[:delivery_date]} type="date" label="Delivery date" />
          </div>

          <h3 class="mt-6 mb-2 text-lg font-medium">Shipping Address</h3>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input field={@form[:shipping_street]} type="text" label="Street" />
            <.input field={@form[:shipping_city]} type="text" label="City" />
            <.input field={@form[:shipping_state]} type="text" label="State" />
            <.input field={@form[:shipping_zip]} type="text" label="ZIP" />
            <.input field={@form[:shipping_country]} type="text" label="Country" />
          </div>

          <h3 class="mt-6 mb-2 text-lg font-medium">Billing Address</h3>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input field={@form[:billing_street]} type="text" label="Street" />
            <.input field={@form[:billing_city]} type="text" label="City" />
            <.input field={@form[:billing_state]} type="text" label="State" />
            <.input field={@form[:billing_zip]} type="text" label="ZIP" />
            <.input field={@form[:billing_country]} type="text" label="Country" />
          </div>

          <:actions>
            <.button phx-disable-with="Placing..." disabled={Enum.empty?(@cart_items)}>
              Place Order
            </.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="lg:col-span-1">
        <section class="rounded border border-stone-200 bg-white p-4">
          <h3 class="mb-2 text-lg font-medium">Order Summary</h3>
          <ul class="divide-y">
            <li :for={item <- @cart_items} class="py-2 text-sm">
              <div class="flex justify-between">
                <span class="text-stone-700">{item.product.name}</span>
                <span class="text-stone-700">{format_money(@settings.currency, item.price)}</span>
              </div>
              <div class="text-stone-500">Qty: {item.quantity}</div>
            </li>
          </ul>
          <div :if={Enum.empty?(@cart_items)} class="py-6 text-center text-stone-500">
            Your cart is empty
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    cart = socket.assigns.cart && Ash.load!(socket.assigns.cart, items: [:product])
    items = (cart && cart.items) || []

    {:ok,
     socket
     |> assign(:cart_items, items)
     |> assign(:order_reference, nil)
     |> assign(:form, new_checkout_form())}
  end

  @impl true
  def handle_event("validate", %{"checkout" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "checkout"))}
  end

  @impl true
  def handle_event("place_order", %{"checkout" => params}, socket) do
    with {:ok, customer} <- upsert_customer(params),
         {:ok, order} <- create_order(socket, customer, params) do
      # Clear cart items but keep cart id in session by emptying items
      _ = maybe_clear_cart(socket.assigns.cart)

      # Try to send confirmation email (best effort)
      _ =
        order.id
        |> Orders.get_order_by_id!(load: [items: [product: [:name]], customer: [:email]])
        |> Craftday.Orders.Emails.deliver_order_confirmation()

      {:noreply,
       socket
       |> put_flash(:info, "Order placed successfully")
       |> assign(:order_reference, order.reference)}
    else
      {:error, %AshPhoenix.Form{} = form} ->
        Logger.error("checkout/place_order form error: #{inspect(form, pretty: true)}")
        {:noreply, assign(socket, :form, form)}

      {:error, reason} ->
        Logger.error("checkout/place_order error: #{inspect(reason, pretty: true)}")
        {:noreply, put_flash(socket, :error, "Failed to place order")}
    end
  end

  defp new_checkout_form do
    to_form(
      %{
        "first_name" => nil,
        "last_name" => nil,
        "email" => nil,
        "phone" => nil,
        "delivery_date" => Date.to_iso8601(Date.utc_today()),
        # shipping
        "shipping_street" => nil,
        "shipping_city" => nil,
        "shipping_state" => nil,
        "shipping_zip" => nil,
        "shipping_country" => nil,
        # billing
        "billing_street" => nil,
        "billing_city" => nil,
        "billing_state" => nil,
        "billing_zip" => nil,
        "billing_country" => nil
      },
      as: "checkout"
    )
  end

  defp upsert_customer(%{"email" => email} = params) when is_binary(email) and email != "" do
    case CRM.get_customer_by_email(email) do
      {:ok, %Customer{} = customer} -> {:ok, customer}
      {:ok, nil} -> create_or_update_customer(params)
      {:error, _} -> create_or_update_customer(params)
    end
  end

  defp upsert_customer(params), do: create_or_update_customer(params)

  defp create_or_update_customer(params) do
    email = blank_to_nil(Map.get(params, "email"))

    shipping =
      address_from_params(
        params,
        "shipping_street",
        "shipping_city",
        "shipping_state",
        "shipping_zip",
        "shipping_country"
      )

    billing =
      address_from_params(
        params,
        "billing_street",
        "billing_city",
        "billing_state",
        "billing_zip",
        "billing_country"
      )

    base_attrs = %{
      type: :individual,
      first_name: Map.get(params, "first_name"),
      last_name: Map.get(params, "last_name"),
      email: email,
      phone: blank_to_nil(Map.get(params, "phone")),
      shipping_address: shipping,
      billing_address: billing
    }

    case email && CRM.get_customer_by_email(email) do
      {:ok, %Customer{} = existing} ->
        # Update addresses if provided and present, keep existing names
        update_attrs = Map.take(base_attrs, [:shipping_address, :billing_address, :phone])

        existing
        |> Ash.Changeset.for_update(:update, update_attrs)
        |> Ash.update()

      _ ->
        Customer
        |> Ash.Changeset.for_create(:create, base_attrs)
        |> Ash.create()
    end
  end

  defp create_order(socket, customer, params) do
    cart = Ash.load!(socket.assigns.cart, items: [:product])
    items = cart.items || []

    items_arg =
      Enum.map(items, fn item ->
        %{
          product_id: item.product_id,
          quantity: Decimal.new(item.quantity),
          unit_price: item.price || item.product.price
        }
      end)

    tz = socket.assigns.time_zone || "Etc/UTC"

    delivery_date =
      case Map.get(params, "delivery_date") do
        <<_::binary>> = date_str ->
          date_str |> Date.from_iso8601!() |> DateTime.new!(~T[09:00:00], tz)

        _ ->
          DateTime.new!(Date.utc_today(), ~T[09:00:00], tz)
      end

    attrs = %{
      customer_id: customer.id,
      delivery_date: delivery_date,
      items: items_arg
    }

    Orders.Order
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  defp maybe_clear_cart(nil), do: :ok

  defp maybe_clear_cart(cart) do
    case Cart.update_cart(cart, %{items: []}) do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp address_from_params(params, street_key, city_key, state_key, zip_key, country_key) do
    address = %{
      street: blank_to_nil(Map.get(params, street_key)),
      city: blank_to_nil(Map.get(params, city_key)),
      state: blank_to_nil(Map.get(params, state_key)),
      zip: blank_to_nil(Map.get(params, zip_key)),
      country: blank_to_nil(Map.get(params, country_key))
    }

    # Return nil if all fields are nil
    if Enum.all?(address, fn {_k, v} -> is_nil(v) end), do: nil, else: address
  end
end
