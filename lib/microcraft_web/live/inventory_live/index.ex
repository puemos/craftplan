defmodule MicrocraftWeb.InventoryLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Inventory
  alias Microcraft.InventoryForecasting
  alias Microcraft.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Inventory" path={~p"/manage/inventory"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link :if={@live_action == :index} patch={~p"/manage/inventory/new"}>
          <.button>New Material</.button>
        </.link>
      </:actions>
    </.header>

    <.tabs id="inventory-tabs">
      <:tab label="All Materials" path={~p"/manage/inventory"} selected?={@live_action == :index}>
        <.table
          id="materials"
          rows={@streams.materials}
          row_id={fn {dom_id, _} -> dom_id end}
          row_click={fn {_, material} -> JS.navigate(~p"/manage/inventory/#{material.sku}") end}
        >
          <:empty>
            <div class="block py-4 pr-6">
              <span class={["relative"]}>
                No materials found
              </span>
            </div>
          </:empty>
          <:col :let={{_, material}} label="Material">{material.name}</:col>
          <:col :let={{_, material}} label="SKU">
            <.kbd>
              {material.sku}
            </.kbd>
          </:col>
          <:col :let={{_, material}} label="Current Stock">
            {format_amount(material.unit, material.current_stock)}
          </:col>
          <:col :let={{_, material}} label="Price">
            {format_money(@settings.currency, material.price)} per {material.unit}
          </:col>

          <:action :let={{_, material}}>
            <div class="sr-only">
              <.link navigate={~p"/manage/inventory/#{material.sku}"}>Show</.link>
            </div>
          </:action>
          <:action :let={{_, material}}>
            <.link
              phx-click={JS.push("delete", value: %{id: material.id}) |> hide("##{material.sku}")}
              data-confirm="Are you sure?"
            >
              <.button size={:sm} variant={:danger}>
                Delete
              </.button>
            </.link>
          </:action>
        </.table>
      </:tab>

      <:tab
        label="Forecast"
        path={~p"/manage/inventory/forecast"}
        selected?={@live_action == :forecast}
      >
        <div class="mt-4">
          <div class="mt-8">
            <div
              id="controls"
              class="border-gray-200/70 flex items-center justify-between border-b pb-4"
            >
              <div class="flex items-center space-x-2">
                <span class="text-xl font-medium text-stone-700">
                  {Calendar.strftime(List.first(@days_range), "%B %Y")}
                </span>
              </div>
              <div class="flex items-center">
                <button
                  phx-click="today"
                  size={:sm}
                  variant={:outline}
                  class="flex cursor-pointer items-center rounded-l-md border-y border-l border-gray-300 bg-white px-3 py-1 text-xs font-medium hover:bg-gray-50 disabled:cursor-default disabled:bg-gray-100 disabled:text-gray-400"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="mr-1 h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                    />
                  </svg>
                  Today
                </button>
                <button
                  phx-click="next_week"
                  size={:sm}
                  class="px-[6px] cursor-pointer rounded-r-md border border-gray-300 bg-white py-1 hover:bg-gray-50"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                  </svg>
                </button>
              </div>
            </div>
            <div class="min-w-[1000px]">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class={[
                      "w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 text-left font-normal"
                    ]}>
                      Material
                    </th>
                    <th
                      :for={{day, _index} <- Enum.with_index(@days_range)}
                      class={
                        [
                          "w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 pl-4 font-normal last:border-r-0"
                        ]
                        |> Enum.filter(& &1)
                        |> Enum.join("  ")
                      }
                    >
                      <div class={["flex items-center justify-center"]}>
                        <div class={[
                          "inline-flex items-center justify-center space-x-1 rounded px-2",
                          is_today?(day) && "bg-stone-500 text-white"
                        ]}>
                          <div>{format_day_name(day)}</div>
                          <div>{format_short_date(day, @time_zone)}</div>
                        </div>
                      </div>
                    </th>
                    <th class="w-1/7 border-stone-200 p-0 pt-4 pb-4 pl-2 font-normal">
                      Weekly total
                    </th>
                  </tr>
                </thead>
                <tbody class="text-sm leading-6 text-stone-700">
                  <tr :for={{material, material_data} <- @materials_requirements}>
                    <td class="border-t border-r border-t-stone-200 border-r-stone-200 py-2 pr-2 text-left font-medium">
                      {material.name}
                    </td>
                    <td
                      :for={
                        {
                          {day_quantity, day},
                          index
                        } <- Enum.with_index(material_data.quantities)
                      }
                      phx-click={
                        Decimal.compare(day_quantity, Decimal.new(0)) == :gt &&
                          "view_material_details"
                      }
                      phx-value-date={
                        Decimal.compare(day_quantity, Decimal.new(0)) == :gt && Date.to_iso8601(day)
                      }
                      phx-value-material={
                        Decimal.compare(day_quantity, Decimal.new(0)) == :gt && material.id
                      }
                      class={[
                        "relative border-t border-r border-t-stone-200 border-r-stone-200 p-2 text-center text-sm",
                        (Decimal.lt?(Enum.at(material_data.balance_cells, index), day_quantity) and
                           Decimal.compare(day_quantity, Decimal.new(0)) != :eq) && "bg-red-50",
                        Decimal.compare(day_quantity, Decimal.new(0)) == :gt &&
                          "cursor-pointer hover:bg-stone-100"
                      ]}
                    >
                      <.icon
                        :if={
                          Decimal.lt?(Enum.at(material_data.balance_cells, index), day_quantity) and
                            Decimal.compare(day_quantity, Decimal.new(0)) != :eq
                        }
                        name="hero-exclamation-triangle"
                        class="absolute top-2 left-1/2 h-5 w-5 -translate-x-1/2 text-red-300"
                      />
                      <div
                        :if={Decimal.compare(day_quantity, Decimal.new(0)) == :gt}
                        class="space-y-1.5 py-0.5 text-center"
                      >
                        <div class={[
                          "text-center font-medium",
                          Decimal.lt?(Enum.at(material_data.balance_cells, index), day_quantity) &&
                            "underline decoration-red-300 decoration-2 underline-offset-4"
                        ]}>
                          {format_amount(material.unit, day_quantity)}
                        </div>
                      </div>
                      <div
                        :if={Decimal.compare(day_quantity, Decimal.new(0)) != :gt}
                        class="py-4 text-center text-stone-400"
                      >
                      </div>
                    </td>
                    <td class={["border-t border-t-stone-200 p-2 text-sm"]}>
                      <div class="space-y-1.5 py-0.5">
                        <div>
                          <div class="text-xs text-stone-500">Total need:</div>
                          <div class={["font-medium"]}>
                            {format_amount(material.unit, material_data.total_quantity)}
                          </div>
                        </div>
                        <div>
                          <div class="text-xs text-stone-500">Final balance:</div>
                          <div class={[
                            "font-medium",
                            Decimal.lt?(material_data.final_balance, Decimal.new(0)) &&
                              "underline decoration-red-300 decoration-2 underline-offset-4"
                          ]}>
                            {format_amount(material.unit, material_data.final_balance)}
                          </div>
                        </div>
                      </div>
                    </td>
                  </tr>

                  <tr :if={@materials_requirements |> Enum.empty?()}>
                    <td colspan="9" class="border-t border-t-stone-200 p-4 text-center text-stone-500">
                      No materials requirements for this period
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </:tab>
    </.tabs>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="material-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory")}
    >
      <.live_component
        module={MicrocraftWeb.InventoryLive.FormComponentMaterial}
        id={(@material && @material.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        material={@material}
        settings={@settings}
        patch={~p"/manage/inventory"}
      />
    </.modal>

    <.modal
      :if={@selected_material_date && @selected_material}
      id="material-details-modal"
      show
      on_cancel={JS.push("close_material_modal")}
    >
      <.header>
        <div class="flex flex-row items-center justify-between gap-1">
          <div>{@selected_material.name}</div>
          <div>for</div>
          <div class="flex flex-row items-center gap-1 text-stone-500 underline decoration-dotted underline-offset-2">
            {format_day_name(@selected_material_date)}
            {format_short_date(@selected_material_date, @time_zone)}
          </div>
        </div>
      </.header>

      <div class="py-4">
        <div :if={@material_details && !Enum.empty?(@material_details)} class="space-y-4">
          <.table id="material-products" rows={@material_details}>
            <:col :let={{product, _items}} label="Product">
              <div class="font-medium">{product.name}</div>
            </:col>
            <:col :let={{_product, items}} label="Order References">
              <div class="grid grid-cols-1 gap-1 text-sm">
                <div :for={item <- items.order_items}>
                  <.kbd>
                    {format_reference(item.order.reference)}
                  </.kbd>
                </div>
              </div>
            </:col>
            <:col :let={{_product, items}} label="Total Required">
              <div class="text-sm">
                {format_amount(@selected_material.unit, items.total_quantity)}
              </div>
            </:col>
            <:empty>
              <div class="py-4 text-center text-stone-500">
                No product details found for this material
              </div>
            </:empty>
          </.table>
        </div>

        <div
          :if={!@material_details || Enum.empty?(@material_details)}
          class="py-8 text-center text-stone-500"
        >
          No details found for this material on this date
        </div>
      </div>

      <footer>
        <.button variant={:outline} phx-click="close_material_modal">Close</.button>
        <.link
          patch={~p"/manage/inventory/#{@selected_material.sku}/adjust"}
          phx-click={JS.push_focus()}
        >
          <.button>Adjust Stock</.button>
        </.link>
      </footer>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    days_range = generate_week_range(today)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket =
      socket
      |> assign(:today, today)
      |> assign(:days_range, days_range)
      |> assign(:materials_requirements, materials_requirements)
      |> assign(:selected_material_date, nil)
      |> assign(:selected_material, nil)
      |> assign(:material_details, nil)
      |> assign(:material_day_quantity, nil)
      |> assign(:material_day_balance, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Material")
    |> assign(:material, nil)
  end

  defp apply_action(socket, :index, _params) do
    # Reload materials when returning to index
    materials =
      Inventory.list_materials!(
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:current_stock]
      )

    socket
    |> stream(:materials, materials, reset: true)
    |> assign(:page_title, "Inventory")
    |> assign(:material, nil)
  end

  defp apply_action(socket, :forecast, _params) do
    today = Date.utc_today()
    days_range = generate_week_range(today)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket
    |> assign(:page_title, "Inventory Forecast")
    |> assign(:material, nil)
    |> assign(:today, today)
    |> assign(:days_range, days_range)
    |> assign(:materials_requirements, materials_requirements)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    material =
      Inventory.get_material_by_id!(id,
        load: [:current_stock],
        actor: socket.assigns[:current_user]
      )

    socket
    |> assign(:page_title, "Edit Material")
    |> assign(:material, material)
  end

  @impl true
  def handle_event("view_material_details", %{"date" => date_str, "material" => material_id}, socket) do
    date = Date.from_iso8601!(date_str)
    material = Inventory.get_material_by_id!(material_id)

    # Get material day quantity
    {day_quantity, day_balance} =
      InventoryForecasting.get_material_day_info(
        material,
        date,
        socket.assigns.materials_requirements
      )

    # Get details of orders/products using this material on this day
    start_time = DateTime.new!(date, ~T[00:00:00], socket.assigns.time_zone)
    end_time = DateTime.new!(date, ~T[23:59:59], socket.assigns.time_zone)

    orders =
      Orders.list_orders!(
        %{delivery_date_start: start_time, delivery_date_end: end_time},
        load: [
          :reference,
          items: [
            :quantity,
            product: [:name, recipe: [components: [material: :id]]]
          ]
        ]
      )

    details = InventoryForecasting.get_material_usage_details(material, orders)

    {:noreply,
     socket
     |> assign(:selected_material_date, date)
     |> assign(:selected_material, material)
     |> assign(:material_details, details)
     |> assign(:material_day_quantity, day_quantity)
     |> assign(:material_day_balance, day_balance)}
  end

  @impl true
  def handle_event("close_material_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_material_date, nil)
     |> assign(:selected_material, nil)
     |> assign(:material_details, nil)
     |> assign(:material_day_quantity, nil)
     |> assign(:material_day_balance, nil)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    # Move the date range forward by 7 days
    new_start = Date.add(List.first(socket.assigns.days_range), 7)
    days_range = generate_week_range(new_start)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    # Reset to current day and forward
    today = Date.utc_today()
    days_range = generate_week_range(today)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:today, today)
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Inventory.get_material_by_id!()
         |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Material deleted successfully")
         |> stream_delete(:materials, %{id: id})}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete material.")}
    end
  end

  @impl true
  def handle_info({:saved, material}, socket) do
    material = Ash.load!(material, :current_stock)

    {:noreply, stream_insert(socket, :materials, material)}
  end

  defp format_day_name(date) do
    day_of_week = Date.day_of_week(date)
    Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), day_of_week - 1)
  end

  @doc """
  Generates a range of dates starting from a given date
  """
  def generate_week_range(start_date, days \\ 7) do
    # Generate range starting from the day itself
    Enum.map(0..(days - 1), fn day_offset ->
      Date.add(start_date, day_offset)
    end)
  end

  defp prepare_materials_requirements(socket, days_range) do
    first_day = List.first(days_range)
    last_day = List.last(days_range)
    time_zone = socket.assigns.time_zone

    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: DateTime.new!(first_day, ~T[00:00:00], time_zone),
          delivery_date_end: DateTime.new!(last_day, ~T[23:59:59], time_zone)
        },
        load: [
          :items,
          items: [
            product: [:recipe, recipe: [components: [material: [:current_stock, :unit, :sku]]]]
          ]
        ]
      )

    InventoryForecasting.prepare_materials_requirements(days_range, orders)
  end
end
