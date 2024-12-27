defmodule MicrocraftWeb.OrderLive.FormComponent do
  @moduledoc false
  use MicrocraftWeb, :live_component

  alias Microcraft.CRM
  alias Microcraft.Orders
  alias Microcraft.Products

  @steps [
    %{number: 1, title: "Customer", description: "Select customer"},
    %{number: 2, title: "Delivery", description: "Choose delivery date"},
    %{number: 3, title: "Products", description: "Select products"},
    %{number: 4, title: "Address", description: "Delivery details"},
    %{number: 5, title: "Payment", description: "Payment and notes"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.simple_form
        for={@form}
        id="order-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <%!-- Step Progress Indicator --%>
        <div class="mb-8">
          <nav aria-label="Progress">
            <ol role="list" class="flex justify-start space-x-2">
              <%= for {step, _index} <- Enum.with_index(@steps) do %>
                <li class={[
                  "w-full"
                ]}>
                  <div class={[
                    "flex flex-row items-center w-full"
                  ]}>
                    <span class={[
                      "flex items-center justify-center w-8 h-8 rounded-full text-sm font-semibold transition-colors",
                      "#{if @current_step > step.number, do: ~c"bg-emerald-600 text-white"}",
                      "#{if @current_step == step.number, do: ~c"bg-stone-600 text-white border-2 border-stone-600"}",
                      "#{if @current_step < step.number, do: ~c"bg-stone-100 text-stone-400 border-2 border-stone-200"}"
                    ]}>
                      <%= if @current_step > step.number do %>
                        <.icon name="hero-check" class="w-5 h-5" />
                      <% else %>
                        {step.number}
                      <% end %>
                    </span>
                    <span class="text-xs ml-2 font-medium text-stone-600">
                      {step.title}
                    </span>
                  </div>
                </li>
              <% end %>
            </ol>
          </nav>
        </div>

        <div class="space-y-8 bg-white mt-4">
          <%!-- Step 1: Customer Information --%>
          <div class={if @current_step == 1, do: "block", else: "hidden"}>
            <div :if={@action == :new}>
              <.input
                field={@form[:customer_id]}
                type="select"
                label="Customer"
                options={@customers}
                prompt="Select a customer"
              />
            </div>
          </div>

          <%!-- Step 2: Delivery Information --%>
          <div class={if @current_step == 2, do: "block", else: "hidden"}>
            <.input
              field={@form[:delivery_date]}
              type="date"
              label="Delivery Date"
              min={Date.utc_today() |> Date.add(1) |> Date.to_string()}
              phx-target={@myself}
            />
          </div>

          <%!-- Step 3: Product Selection --%>
          <div class={if @current_step == 3, do: "block", else: "hidden"}>
            <label class="text-sm font-semibold leading-6 text-zinc-800">
              Select Products
            </label>
            <%= if @form[:delivery_date].value != nil and @form[:delivery_date].value != "" do %>
              <div class="grid grid-cols-1 gap-4 mt-4">
                <div :for={product <- @products} class="border rounded-md p-4 border-stone-200 w-full">
                  <% availability =
                    Map.get(@availability, product.id, %{
                      available_quantity: product.daily_capacity,
                      total_ordered: 0,
                      daily_capacity: product.daily_capacity
                    }) %>

                  <div class="flex items-center justify-between">
                    <!-- Product Details -->
                    <div>
                      <h3 class="font-medium text-stone-900">
                        {product.name}
                      </h3>
                      <p class="mt-1 text-sm text-stone-500">
                        Available: {availability.available_quantity} of {availability.daily_capacity}
                      </p>
                      <p :if={availability.available_quantity == 0} class="mt-1 text-sm text-red-600">
                        Fully booked for this date
                      </p>
                    </div>
                    <!-- Price and Quantity Controls -->
                    <div class="flex items-center space-x-8">
                      <div class="text-right flex flex-col">
                        <div class="mt-1 text-sm text-stone-500">
                          <%!-- Unit price: {Number.Currency.number_to_currency(product.unit_price)} --%>
                        </div>
                        <div class="mt-1 text-sm text-stone-500">
                          <%!-- Total: {Number.Currency.number_to_currency( --%>
                          Decimal.mult(product.unit_price, Map.get(@quantities, product.id, 0))
                          )}
                        </div>
                      </div>
                      <div class="flex items-center space-x-2">
                        <button
                          type="button"
                          phx-click="decrease_quantity"
                          phx-value-product-id={product.id}
                          phx-target={@myself}
                          disabled={Map.get(@quantities, product.id, 0) == 0}
                        >
                          <.icon name="hero-minus-small" class="h-5 w-5" />
                        </button>

                        <span class="w-12 text-center text-lg text-stone-900">
                          {Map.get(@quantities, product.id, 0)}
                        </span>

                        <button
                          type="button"
                          phx-click="increase_quantity"
                          phx-value-product-id={product.id}
                          phx-target={@myself}
                          disabled={
                            Map.get(@quantities, product.id, 0) > availability.available_quantity
                          }
                        >
                          <.icon name="hero-plus-small" class="h-5 w-5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="text-sm text-zinc-500 p-4 text-center border rounded-lg">
                Please select a delivery date to see available products
              </div>
            <% end %>
          </div>

          <%!-- Step 4: Delivery Address --%>
          <div class={if @current_step == 4, do: "block", else: "hidden"}>
            <label class="text-sm font-semibold leading-6 text-zinc-800">
              Delivery Address
            </label>

            <.inputs_for :let={f_addr} field={@form[:delivery_address]}>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <.input field={f_addr[:street]} type="text" label="Street" />
                <.input field={f_addr[:city]} type="text" label="City" />
                <.input field={f_addr[:postal_code]} type="text" label="Postal Code" />
                <.input field={f_addr[:country]} type="text" label="Country" />
              </div>
            </.inputs_for>
          </div>

          <%!-- Step 5: Payment and Notes --%>
          <div class={if @current_step == 5, do: "block", else: "hidden"}>
            <.input
              field={@form[:payment_method]}
              type="select"
              label="Payment Method"
              options={[{"On Delivery", :on_delivery}]}
            />
            <.input field={@form[:notes]} type="textarea" label="Additional Notes" />
          </div>
        </div>

        <%!-- Navigation Buttons --%>
        <div class="flex justify-between mt-8 pt-4">
          <.button
            type="button"
            phx-click="previous_step"
            phx-target={@myself}
            class={
              "#{if @current_step == 1, do: ~c"invisible", else: ~c"visible"}"
            }
          >
            ← Previous
          </.button>

          <%= if @current_step == length(@steps) do %>
            <.button type="submit" phx-disable-with="Saving...">
              Complete Order
            </.button>
          <% else %>
            <.button type="button" phx-click="next_step" phx-target={@myself}>
              Next →
            </.button>
          <% end %>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{order: order} = assigns, socket) do
    changeset = Orders.change_order(order)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign_products()
     |> assign_customers()
     |> assign(:delivery_date, nil)
     |> assign_new(:quantities, fn -> %{} end)
     |> assign_new(:availability, fn -> %{} end)
     |> assign(:current_step, 1)
     |> assign(:steps, @steps)
     |> maybe_load_availability()}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply,
     assign(socket, :current_step, min(socket.assigns.current_step + 1, length(@steps)))}
  end

  def handle_event("previous_step", _params, socket) do
    {:noreply, assign(socket, :current_step, max(socket.assigns.current_step - 1, 1))}
  end

  def handle_event("set_step", %{"step" => step}, socket) do
    step = String.to_integer(step)

    if step <= socket.assigns.current_step do
      {:noreply, assign(socket, :current_step, step)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", %{"order" => params}, socket) do
    changeset =
      socket.assigns.order
      |> Orders.change_order(params)
      |> Map.put(:action, :validate)

    socket = assign_form(socket, changeset)

    socket =
      case {params["delivery_date"], params["customer_id"]} do
        {new_date, _} when new_date != "" and new_date != socket.assigns.delivery_date ->
          socket
          |> load_availability(new_date)
          |> assign(:delivery_date, new_date)
          |> assign(:quantities, %{})

        {_, customer_id}
        when customer_id != "" and customer_id != socket.assigns.form.data.customer_id ->
          customer = CRM.get_customer!(customer_id)

          changeset =
            socket.assigns.form.source
            |> Ecto.Changeset.put_embed(:delivery_address, customer.shipping_address)
            |> Map.put(:action, :validate)

          assign_form(socket, changeset)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"order" => order_params}, socket) do
    current_params = socket.assigns.form.params || %{}
    merged_params = Map.merge(current_params, order_params)

    order_items =
      socket.assigns.quantities
      |> Enum.map(fn {product_id, quantity} ->
        product = Products.get_product!(product_id)

        %{
          product_id: product_id,
          quantity: quantity,
          unit_price: product.unit_price,
          unit_type: product.unit_type
        }
      end)
      |> Enum.filter(fn %{quantity: quantity} -> quantity > 0 end)

    merged_params = Map.put(merged_params, "order_items", order_items)
    save_order(socket, socket.assigns.action, merged_params)
  end

  def handle_event("increase_quantity", %{"product-id" => product_id}, socket) do
    quantities = socket.assigns.quantities
    current_quantity = Map.get(quantities, product_id, 0)
    availability = get_product_availability(socket, product_id)

    if current_quantity < availability.available_quantity do
      new_quantities = Map.put(quantities, product_id, current_quantity + 1)
      {:noreply, assign(socket, :quantities, new_quantities)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("decrease_quantity", %{"product-id" => product_id}, socket) do
    quantities = socket.assigns.quantities
    current_quantity = Map.get(quantities, product_id, 0)

    if current_quantity > 0 do
      new_quantities = Map.put(quantities, product_id, current_quantity - 1)
      {:noreply, assign(socket, :quantities, new_quantities)}
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp maybe_load_availability(socket) do
    case socket.assigns.form.source.changes[:delivery_date] ||
           socket.assigns.form.source.data.delivery_date do
      nil -> socket
      date -> load_availability(socket, date)
    end
  end

  defp load_availability(socket, date) do
    if date == "" do
      socket
    else
      product_ids = Enum.map(socket.assigns.products, & &1.id)
      availability = Orders.get_products_availability(product_ids, date)
      assign(socket, :availability, availability)
    end
  end

  defp get_product_availability(socket, product_id) do
    Map.get(socket.assigns.availability, product_id, %{
      available_quantity: 0,
      total_ordered: 0,
      daily_capacity: 0
    })
  end

  defp save_order(socket, :new, order_params) do
    case Orders.create_order(order_params) do
      {:ok, order} ->
        notify_parent({:saved, order})

        {:noreply,
         socket
         |> put_flash(:info, "Order created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp assign_customers(socket) do
    customers = Enum.map(CRM.list_customers(), &{&1.name, &1.id})
    assign(socket, :customers, customers)
  end

  defp assign_products(socket) do
    products = Products.list_products()
    assign(socket, :products, products)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
