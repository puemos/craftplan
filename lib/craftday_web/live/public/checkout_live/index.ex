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
            <.input
              field={@form[:delivery_method]}
              type="select"
              label="Delivery method"
              options={[{"Delivery", :delivery}, {"Pickup", :pickup}]}
            />
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

          <div :if={!Enum.empty?(@cart_items)} class="mt-4">
            <.list>
              <:item title="Subtotal">
                {format_money(@settings.currency, @preview_totals.subtotal)}
              </:item>
              <:item title="Shipping">
                {format_money(@settings.currency, @preview_totals.shipping_total)}
              </:item>
              <:item title="Tax">
                {format_money(@settings.currency, @preview_totals.tax_total)}
              </:item>
              <:item title="Total">
                {format_money(@settings.currency, @preview_totals.total)}
              </:item>
            </.list>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    cart =
      socket.assigns.cart &&
        Ash.load!(socket.assigns.cart, [items: [:product]], context: %{cart_id: socket.assigns.cart.id})

    items = (cart && cart.items) || []

    form = new_checkout_form()
    preview = compute_preview_totals(socket, items, form[:delivery_method].value)

    {:ok,
     socket
     |> assign(:cart_items, items)
     |> assign(:order_reference, nil)
     |> assign(:preview_totals, preview)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"checkout" => params}, socket) do
    form = to_form(params, as: "checkout")
    delivery_method = Map.get(params, "delivery_method") || :delivery
    preview = compute_preview_totals(socket, socket.assigns.cart_items, delivery_method)
    {:noreply, socket |> assign(:form, form) |> assign(:preview_totals, preview)}
  end

  @impl true
  def handle_event("place_order", %{"checkout" => params}, socket) do
    with {:ok, customer} <- upsert_customer(params),
         {:ok, order} <- create_order(socket, customer, params) do
      # Clear cart items but keep cart id in session by emptying items
      _ = maybe_clear_cart(socket.assigns.cart)

      # Try to send confirmation email (best effort). Skip for anonymous to avoid policy loads.
      _ =
        if socket.assigns[:current_user] do
          order
          |> Ash.load!(items: [product: [:name]], customer: [:email])
          |> Craftday.Orders.Emails.deliver_order_confirmation()
        else
          :ok
        end

      {:noreply,
       socket
       |> put_flash(:info, "Order placed successfully")
       |> assign(:order_reference, order.reference)}
    else
      {:error, %AshPhoenix.Form{} = form} ->
        Logger.error("checkout/place_order form error: #{inspect(form, pretty: true)}")
        {:noreply, assign(socket, :form, form)}

      {:error, {:lead_time, min_date}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Earliest available date is #{Calendar.strftime(min_date, "%Y-%m-%d")}"
         )}

      {:error, :daily_capacity} ->
        {:noreply, put_flash(socket, :error, "Daily capacity reached for that date.")}

      {:error, {:capacity, name, available}} ->
        msg =
          if Decimal.compare(available, Decimal.new(0)) == :gt do
            "Capacity reached for #{name} on that date. Available: #{Decimal.to_string(available)}"
          else
            "Capacity reached for #{name} on that date. Please choose another date."
          end

        {:noreply, put_flash(socket, :error, msg)}

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
        "delivery_method" => :delivery,
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
    case CRM.get_customer_by_email(%{email: email}) do
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

    case email && CRM.get_customer_by_email(%{email: email}) do
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
    cart =
      Ash.load!(socket.assigns.cart, [items: [:product]], context: %{cart_id: socket.assigns.cart.id})

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

    # Lead time validation
    lead_days = socket.assigns.settings.lead_time_days || 0
    min_date = Date.add(Date.utc_today(), lead_days)

    if Date.before?(DateTime.to_date(delivery_date), min_date) do
      return_error = {:error, {:lead_time, min_date}}
      return_error
    else
      :ok
    end

    delivery_method =
      case Map.get(params, "delivery_method") do
        "pickup" -> :pickup
        :pickup -> :pickup
        _ -> :delivery
      end

    shipping_total =
      case {delivery_method, socket.assigns.settings.shipping_flat} do
        {:delivery, %Decimal{} = flat} -> flat
        {:delivery, flat} when is_number(flat) -> Decimal.new(flat)
        _ -> Decimal.new(0)
      end

    # Enforce per-product daily capacity if configured on product
    case ensure_product_capacity(socket, items, delivery_date) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # Global daily capacity (orders per day)
    if (socket.assigns.settings.daily_capacity || 0) > 0 do
      day_count =
        Craftday.Orders.Order
        |> Ash.Query.for_read(:for_day, %{
          delivery_date_start: DateTime.new!(DateTime.to_date(delivery_date), ~T[00:00:00], tz),
          delivery_date_end: DateTime.new!(DateTime.to_date(delivery_date), ~T[23:59:59], tz)
        })
        |> Ash.count!()

      if day_count >= socket.assigns.settings.daily_capacity do
        return_error = {:error, :daily_capacity}
        return_error
      else
        :ok
      end
    else
      :ok
    end

    attrs = %{
      customer_id: customer.id,
      delivery_date: delivery_date,
      items: items_arg,
      delivery_method: delivery_method,
      shipping_total: shipping_total
    }

    Orders.Order
    |> Ash.Changeset.for_create(:public_create, attrs)
    |> Ash.create()
  end

  defp compute_preview_totals(socket, items, delivery_method) do
    subtotal =
      Enum.reduce(items, Decimal.new(0), fn item, acc ->
        Decimal.add(acc, Decimal.mult(item.price, Decimal.new(item.quantity)))
      end)

    shipping =
      case delivery_method do
        "pickup" -> Decimal.new(0)
        :pickup -> Decimal.new(0)
        _ -> socket.assigns.settings.shipping_flat || Decimal.new(0)
      end

    rate = socket.assigns.settings.tax_rate || Decimal.new(0)
    mode = socket.assigns.settings.tax_mode || :exclusive
    tax_base = subtotal

    tax_total =
      case mode do
        :exclusive ->
          Decimal.mult(tax_base, rate)

        :inclusive ->
          denom = Decimal.add(Decimal.new(1), rate)
          net = Decimal.div(tax_base, denom)
          Decimal.sub(tax_base, net)

        _ ->
          Decimal.new(0)
      end

    total =
      subtotal
      |> Decimal.add(shipping)
      |> Decimal.add(tax_total)

    %{subtotal: subtotal, shipping_total: shipping, tax_total: tax_total, total: total}
  end

  defp ensure_product_capacity(socket, items, %DateTime{} = delivery_dt) do
    # Build required qty per product from cart items
    required_by_product =
      Enum.reduce(items, %{}, fn item, acc ->
        qty = Decimal.new(item.quantity)
        Map.update(acc, item.product_id, qty, &Decimal.add(&1, qty))
      end)

    # Load scheduled quantities for the given day
    tz = socket.assigns.time_zone || "Etc/UTC"
    start_dt = DateTime.new!(DateTime.to_date(delivery_dt), ~T[00:00:00], tz)
    end_dt = DateTime.new!(DateTime.to_date(delivery_dt), ~T[23:59:59], tz)

    scheduled =
      Craftday.Orders.OrderItem
      |> Ash.Query.for_read(:in_range, %{
        start_date: start_dt,
        end_date: end_dt,
        product_ids: Map.keys(required_by_product)
      })
      |> Ash.read!()
      |> Enum.reduce(%{}, fn item, acc ->
        Map.update(acc, item.product_id, item.quantity, &Decimal.add(&1, item.quantity))
      end)

    # Check each product with a max_daily_quantity
    violation =
      items
      |> Enum.map(& &1.product)
      |> Enum.uniq_by(& &1.id)
      |> Enum.find_value(fn product ->
        max = product.max_daily_quantity || 0

        if max <= 0 do
          false
        else
          existing = Map.get(scheduled, product.id, Decimal.new(0))
          incoming = Map.get(required_by_product, product.id, Decimal.new(0))
          max_dec = Decimal.new(max)

          if Decimal.compare(Decimal.add(existing, incoming), max_dec) == :gt do
            available = max_dec |> Decimal.sub(existing) |> Decimal.max(Decimal.new(0))
            {:exceeded, product.name, available}
          else
            false
          end
        end
      end)

    case violation do
      {:exceeded, name, available} ->
        {:error, {:capacity, name, available}}

      _ ->
        :ok
    end
  end

  defp maybe_clear_cart(nil), do: :ok

  defp maybe_clear_cart(cart) do
    case Cart.update_cart(cart, %{items: []}, context: %{cart_id: cart.id}) do
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
