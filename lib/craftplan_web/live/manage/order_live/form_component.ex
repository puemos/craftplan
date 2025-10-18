defmodule CraftplanWeb.OrderLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div>
          <div class="mb-8">
            <.input
              field={@form[:customer_id]}
              type="select"
              label="Customer"
              options={Enum.map(@customers, &{&1.full_name, &1.id})}
            />
          </div>

          <div class="mb-8">
            <.input field={@form[:delivery_date]} type="datetime-local" label="Delivery date" />
            <.timezone />
          </div>

          <.label>Items</.label>
          <div
            id="order-items"
            class="mt-2 grid w-full grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
          >
            <div
              role="row"
              class="col-span-4 grid grid-cols-4 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
            >
              <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0 ">
                Product
              </div>
              <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                Quantity
              </div>
              <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                Total
              </div>
              <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                <span class="opacity-0">Actions</span>
              </div>
            </div>

            <div role="row" class="col-span-4 hidden py-4 text-stone-400 last:block">
              <div class="">
                No items
              </div>
            </div>

            <.inputs_for :let={items_form} field={@form[:items]}>
              <div role="row" class="group col-span-4 grid grid-cols-4 hover:bg-stone-200/40">
                <div class="relative border-r border-b border-stone-200 p-0 last:border-r-0 ">
                  <div class="block py-4 pr-6">
                    <span class="relative">
                      {@products_map[items_form[:product_id].value].name}
                      <.input
                        field={items_form[:product_id]}
                        value={items_form[:product_id].value}
                        type="hidden"
                      />
                      <.input
                        field={items_form[:unit_price]}
                        value={@products_map[items_form[:product_id].value].price}
                        type="hidden"
                      />
                    </span>
                  </div>
                </div>

                <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                  <div class="block py-4 pr-6">
                    <span class="relative -mt-2">
                      <div class="border-b border-dashed border-stone-300">
                        <.input flat={true} field={items_form[:quantity]} type="number" min="1" />
                      </div>
                    </span>
                  </div>
                </div>

                <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                  <div class="block py-4 pr-6">
                    <span class="relative">
                      {format_money(
                        @settings.currency,
                        Decimal.mult(
                          @products_map[items_form[:product_id].value].price || 0,
                          items_form[:quantity].value || 0
                        )
                      )}
                    </span>
                  </div>
                </div>

                <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                  <div class="block py-4 pr-6">
                    <.link
                      class="font-semibold leading-6 text-stone-900 hover:text-stone-700"
                      type="button"
                      phx-click="remove_form"
                      phx-target={@myself}
                      phx-value-path={items_form.name}
                    >
                      Remove
                    </.link>
                  </div>
                </div>
              </div>
            </.inputs_for>

            <div
              :if={not Enum.empty?(@available_products)}
              role="row"
              class="col-span-4 grid grid-cols-4"
            >
              <div class="relative col-span-3 border-r border-b border-stone-200 p-0 last:border-r-0 ">
                <span class="relative">
                  <div class="-mt-2 block py-4 pr-6">
                    <.input
                      phx-change="selected-product-change"
                      name="product_id"
                      type="select"
                      value={@selected_product}
                      options={Enum.map(@available_products, &{&1.name, &1.id})}
                    />
                  </div>
                </span>
              </div>

              <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                <div class="mt-2 block py-4 pr-6">
                  <.link
                    class="font-semibold leading-6 text-stone-900 hover:text-stone-700"
                    type="button"
                    phx-click="add_form"
                    phx-target={@myself}
                    phx-value-path={@form[:items].name}
                  >
                    Add
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <:actions>
          <.button
            variant={:primary}
            disabled={
              not @form.source.changed? || not @form.source.valid? ||
                Enum.empty?((@form.source.forms && @form.source.forms[:items]) || [])
            }
            phx-disable-with="Saving..."
          >
            Save Order
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = assign_form(socket)

    products_map =
      Map.new(assigns.products, fn p -> {p.id, p} end)

    {available_products, selected_product} =
      recompute_availability(socket.assigns.form, assigns.products)

    {:ok,
     socket
     |> assign(:changed, false)
     |> assign(:products_map, products_map)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  @impl true
  def handle_event("validate", %{"order" => order_params}, socket) do
    form = Form.validate(socket.assigns.form, order_params)
    {:noreply, assign(socket, form: form, changed: true)}
  end

  @impl true
  def handle_event("save", %{"order" => order_params, "timezone" => timezone}, socket) do
    datetime = extract_and_parse_datetime(order_params["delivery_date"], timezone)

    order_params =
      order_params
      |> Map.put("delivery_date", datetime)
      |> update_in(["items"], fn items ->
        Map.new(items, fn {k, v} ->
          {k, Map.put(v, "unit_price", socket.assigns.products_map[v["product_id"]].price)}
        end)
      end)

    case Form.submit(socket.assigns.form, params: order_params) do
      {:ok, order} ->
        send(self(), {__MODULE__, {:saved, order}})

        {:noreply,
         socket
         |> put_flash(:info, "Order saved successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("selected-product-change", %{"product_id" => product_id}, socket) do
    {:noreply, assign(socket, :selected_product, product_id)}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form =
      Form.add_form(socket.assigns.form, path, params: %{product_id: socket.assigns.selected_product, quantity: 0})

    {available_products, selected_product} =
      recompute_availability(form, socket.assigns.products)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = Form.remove_form(socket.assigns.form, path)

    {available_products, selected_product} =
      recompute_availability(form, socket.assigns.products)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_products, available_products)
     |> assign(:selected_product, selected_product)}
  end

  defp assign_form(%{assigns: %{order: order}} = socket) do
    form =
      if order do
        Form.for_update(order, :update,
          as: "order",
          actor: socket.assigns.current_user,
          forms: [
            items: [
              type: :list,
              data: order.items,
              resource: Orders.OrderItem,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        Form.for_create(Orders.Order, :create,
          as: "order",
          actor: socket.assigns.current_user,
          forms: [
            items: [
              type: :list,
              resource: Orders.OrderItem,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    assign(socket, :form, to_form(form))
  end

  defp recompute_availability(form, all_products) do
    # Convert existing product IDs to a MapSet for O(1) membership checks
    existing_product_ids =
      form
      |> get_order_items()
      |> Stream.map(&extract_product_id/1)
      |> Stream.reject(&is_nil/1)
      # MapSet automatically removes duplicates, so we don’t need `Enum.uniq/1`
      |> MapSet.new()

    # Reject products whose IDs are in existing_product_ids
    available_products =
      for product <- all_products,
          not MapSet.member?(existing_product_ids, product.id),
          do: product

    # Safely pick the first product, or nil if none available
    selected_product =
      available_products
      |> List.first()
      |> then(&(&1 && &1.id))

    {available_products, selected_product}
  end

  defp get_order_items(form) do
    form.source.forms[:items] || []
  end

  defp extract_product_id(order_item_form) do
    order_item_form.params[:product_id] ||
      (order_item_form.data && order_item_form.data.product_id)
  end

  defp extract_and_parse_datetime(delivery_date, timezone) do
    <<datetime::binary-size(16), _::binary>> = delivery_date

    with {:ok, naive_dt} <- NaiveDateTime.from_iso8601(datetime <> ":00Z"),
         {:ok, dt} <- DateTime.from_naive(naive_dt, timezone) do
      DateTime.to_iso8601(dt)
    else
      _ -> nil
    end
  end
end
