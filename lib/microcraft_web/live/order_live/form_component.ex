defmodule MicrocraftWeb.OrderLive.FormComponent do
  use MicrocraftWeb, :live_component
  alias AshPhoenix.Form
  alias Microcraft.Orders

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
            class="w-full mt-2 grid grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
          >
            <div
              role="row"
              class="col-span-4 grid grid-cols-4 text-sm text-left leading-6 text-stone-500 border-b border-stone-300"
            >
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 ">
                Product
              </div>
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4">
                Quantity
              </div>
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4">
                Total
              </div>
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4">
                <span class="opacity-0">Actions</span>
              </div>
            </div>

            <div role="row" class="col-span-4 last:block hidden py-4 text-stone-400">
              <div class="">
                No items
              </div>
            </div>

            <.inputs_for :let={items_form} field={@form[:items]}>
              <div role="row" class="col-span-4 grid grid-cols-4 group hover:bg-stone-200/40">
                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 ">
                  <div class="block py-4 pr-6">
                    <span class="relative">
                      {@products_map[items_form[:product_id].value].name}
                      <.input
                        field={items_form[:product_id]}
                        value={items_form[:product_id].value}
                        type="hidden"
                      />
                    </span>
                  </div>
                </div>

                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                  <div class="block py-4 pr-6">
                    <span class="relative -mt-2">
                      <div class="border-dashed border-b border-stone-300">
                        <.input flat={true} field={items_form[:quantity]} type="number" min="1" />
                      </div>
                    </span>
                  </div>
                </div>

                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                  <div class="block py-4 pr-6">
                    <span class="relative">
                      {Money.from_float(
                        @settings.currency,
                        Decimal.to_float(
                          Decimal.mult(
                            @products_map[items_form[:product_id].value].price || 0,
                            items_form[:quantity].value || 0
                          )
                        )
                      )}
                    </span>
                  </div>
                </div>

                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
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
              <div class="relative p-0 col-span-3 border-r border-stone-200 border-b last:border-r-0 ">
                <span class="relative">
                  <div class="block py-4 pr-6 -mt-2">
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

              <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                <div class="block py-4 mt-2 pr-6">
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
            disabled={not @form.source.changed? || not @form.source.valid?}
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
      assigns.products
      |> Enum.map(fn p -> {p.id, p} end)
      |> Map.new()

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
    <<datetime::binary-size(16), _::binary>> = order_params["delivery_date"]
    {:ok, datetime} = NaiveDateTime.from_iso8601(datetime <> ":00Z")
    {:ok, datetime} = DateTime.from_naive(datetime, timezone)

    order_params = Map.put(order_params, "delivery_date", DateTime.to_iso8601(datetime))

    case Form.submit(socket.assigns.form, params: order_params) do
      {:ok, order} ->
        send(self(), {__MODULE__, {:saved, order}})

        {:noreply,
         socket
         |> put_flash(:info, "Order saved successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        dbg(form)
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
      AshPhoenix.Form.add_form(socket.assigns.form, path,
        params: %{product_id: socket.assigns.selected_product, quantity: 1}
      )

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
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)

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
        AshPhoenix.Form.for_update(order, :update,
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
        AshPhoenix.Form.for_create(Orders.Order, :create,
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
    existing_product_ids =
      (form.source.forms[:items] || [])
      |> Enum.map(fn order_item_form ->
        order_item_form.params[:product_id] ||
          (order_item_form.data && order_item_form.data.product_id)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    available_products =
      Enum.reject(all_products, fn p -> p.id in existing_product_ids end)

    selected_product =
      case available_products do
        [first | _] -> first.id
        [] -> nil
      end

    {available_products, selected_product}
  end
end
