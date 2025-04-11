defmodule MicrocraftWeb.PlanLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Catalog
  alias Microcraft.Inventory
  alias Microcraft.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Plan" path={~p"/manage/plan"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.button phx-click="previous_week" size={:sm}>Previous</.button>
        <.button phx-click="today" size={:sm}>Today</.button>
        <.button phx-click="next_week" size={:sm}>Next</.button>
      </:actions>
    </.header>

    <div class="mt-4">
      <div class="mt-8 overflow-x-auto">
        <div class="min-w-[1000px]">
          <table class="w-full table-fixed border-collapse">
            <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
              <tr>
                <th
                  :for={{day, index} <- Enum.with_index(@days_range |> Enum.take(7))}
                  class={"#{if index > 0, do: "pl-4"} w-1/7 border-r border-stone-200 p-0 pb-4 font-normal last:border-r-0"}
                >
                  <div>{format_day_name(day)}</div>
                  <div>{format_short_date(day, @time_zone)}</div>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td
                  :for={{day, index} <- Enum.with_index(@days_range |> Enum.take(7))}
                  class={"#{(is_weekend?(day) && "border-t border-t-stone-200") || "border-t border-t-stone-200"} #{if index > 0, do: "border-l", else: ""} #{if index < 6, do: "border-r", else: ""} min-h-[200px] w-1/7 overflow-hidden border-stone-200 bg-white p-2 align-top"}
                >
                  <div class="h-full overflow-y-auto">
                    <div
                      :for={{product, items} <- get_items_for_day(day, @production_items)}
                      phx-click="view_details"
                      phx-value-date={Date.to_iso8601(day)}
                      phx-value-product={product.id}
                      class="group mb-2 cursor-pointer border border-stone-200 p-2 hover:bg-stone-100"
                    >
                      <div class="mb-1.5 flex items-center justify-between gap-2">
                        <span class="truncate text-sm font-medium" title={product.name}>
                          {product.name}
                        </span>
                      </div>
                      <div class="mt-1.5 flex items-center justify-between text-xs text-stone-500">
                        <span>
                          {format_amount(:piece, total_quantity(items))}
                        </span>
                      </div>
                      <div class="mt-1.5 h-1.5 w-full rounded-full bg-stone-200 group-hover:bg-stone-200">
                        <div class="relative h-1.5 w-full">
                          <div
                            class="absolute h-1.5 bg-green-500"
                            style={"width: calc(#{progress_by_status(items, :done)}%)"}
                          >
                          </div>
                        </div>
                      </div>
                      <div class="mt-1.5 flex items-center justify-between text-xs text-stone-500">
                        <span>
                          {format_percentage(
                            Decimal.div(
                              Decimal.new(progress_by_status(items, :done)),
                              Decimal.new(100)
                            )
                          )}% complete
                        </span>
                      </div>
                    </div>

                    <div
                      :if={get_items_for_day(day, @production_items) |> Enum.empty?()}
                      class="flex h-full pt-2 text-sm text-stone-400"
                    >
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <.modal
      :if={@selected_date && @selected_product}
      id="product-details-modal"
      show
      on_cancel={JS.push("close_modal")}
    >
      <.header>
        {@selected_product.name} - {format_short_date(@selected_date, @time_zone)}
      </.header>

      <div class="py-4">
        <div :if={@selected_details} class="space-y-4">
          <.table id="product-orders" rows={@selected_details}>
            <:col :let={item} label="Reference">
              <.kbd class="font-medium">{format_reference(item.order.reference)}</.kbd>
            </:col>
            <:col :let={item} label="Quantity">
              <span class="text-sm">{item.quantity}x</span>
            </:col>
            <:col :let={item} label="Customer">
              <span class="text-sm">{item.order.customer.full_name}</span>
            </:col>
            <:col :let={item} label="Status">
              <form phx-change="update_item_status">
                <input type="hidden" name="item_id" value={item.id} />

                <.input
                  name="status"
                  type="badge-select"
                  value={item.status}
                  options={[
                    {"To Do", "todo"},
                    {"In Progress", "in_progress"},
                    {"Completed", "done"}
                  ]}
                  badge_colors={[
                    {:todo, "#{order_item_status_bg(:todo)} #{order_item_status_color(:todo)}"},
                    {:in_progress,
                     "#{order_item_status_bg(:in_progress)} #{order_item_status_color(:in_progress)}"},
                    {:done, "#{order_item_status_bg(:done)} #{order_item_status_color(:done)}"}
                  ]}
                  flat={true}
                />
              </form>
            </:col>

            <:empty>
              <div class="py-4 text-center text-stone-500">No order items found</div>
            </:empty>
          </.table>
        </div>

        <div :if={!@selected_details} class="py-8 text-center text-stone-500">
          No items found
        </div>
      </div>

      <footer>
        <.button variant={:outline} phx-click="close_modal">Close</.button>
      </footer>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    days_range = generate_week_range(today)

    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket =
      socket
      |> assign(:today, today)
      |> assign(:days_range, days_range)
      |> assign(:production_items, production_items)
      |> assign(:materials_requirements, materials_requirements)
      |> assign(:selected_date, nil)
      |> assign(:selected_product, nil)
      |> assign(:selected_details, nil)
      |> assign(:selected_material_date, nil)
      |> assign(:selected_material, nil)
      |> assign(:material_details, nil)
      |> assign(:material_day_quantity, nil)
      |> assign(:material_day_balance, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, assign(socket, :page_title, page_title(socket.assigns.live_action))}
  end

  @impl true
  def handle_event("view_material_details", %{"date" => date_str, "material" => material_id}, socket) do
    date = Date.from_iso8601!(date_str)
    material = find_material(socket, material_id)
    {day_quantity, day_balance} = get_material_day_info(socket, material, date)
    details = get_material_usage_details(socket, material, date)

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
  def handle_event("previous_week", _params, socket) do
    new_start = Date.add(List.first(socket.assigns.days_range), -7)
    days_range = generate_week_range(new_start)
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    new_start = Date.add(List.first(socket.assigns.days_range), 7)
    days_range = generate_week_range(new_start)
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    today = Date.utc_today()
    days_range = generate_week_range(today)
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:today, today)
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)}
  end

  @impl true
  def handle_event("view_details", %{"date" => date_str, "product" => product_id}, socket) do
    date = Date.from_iso8601!(date_str)
    product = find_product(socket, product_id)
    details = get_product_items_for_day(date, product, socket.assigns.production_items)

    {:noreply,
     socket
     |> assign(:selected_date, date)
     |> assign(:selected_product, product)
     |> assign(:selected_details, details)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_date, nil)
     |> assign(:selected_product, nil)
     |> assign(:selected_details, nil)}
  end

  @impl true
  def handle_event("update_item_status", %{"item_id" => id, "status" => status}, socket) do
    order_item = Orders.get_order_item_by_id!(id, actor: socket.assigns.current_user)

    case Orders.update_item(order_item, %{status: String.to_atom(status)}, actor: socket.assigns.current_user) do
      {:ok, _order_item} ->
        days_range = socket.assigns.days_range
        production_items = load_production_items(socket, days_range)
        materials_requirements = prepare_materials_requirements(socket, days_range)

        selected_details =
          if socket.assigns.selected_product do
            get_product_items_for_day(
              socket.assigns.selected_date,
              socket.assigns.selected_product,
              production_items
            )
          end

        {:noreply,
         socket
         |> assign(:production_items, production_items)
         |> assign(:materials_requirements, materials_requirements)
         |> assign(:selected_details, selected_details)
         |> put_flash(:info, "Item status updated")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp generate_week_range(start_date) do
    Enum.map(0..6, &Date.add(start_date, &1))
  end

  defp is_weekend?(date) do
    day_of_week = Date.day_of_week(date)
    day_of_week == 6 || day_of_week == 7
  end

  defp is_today?(date) do
    Date.compare(date, Date.utc_today()) == :eq
  end

  defp format_day_name(date) do
    day_names = ~w(Mon Tue Wed Thu Fri Sat Sun)

    if is_today?(date) do
      "Today"
    else
      Enum.at(day_names, Date.day_of_week(date) - 1)
    end
  end

  defp load_production_items(socket, days_range) do
    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: days_range |> List.first() |> DateTime.new!(~T[00:00:00], socket.assigns.time_zone),
          delivery_date_end: days_range |> List.last() |> DateTime.new!(~T[23:59:59], socket.assigns.time_zone)
        },
        load: [
          :items,
          :status,
          customer: [:full_name],
          items: [product: [:name]]
        ]
      )

    Enum.flat_map(orders, fn order ->
      day = DateTime.to_date(order.delivery_date)

      order.items
      |> Enum.group_by(& &1.product)
      |> Enum.map(fn {product, items} ->
        production_items =
          Enum.map(items, fn item ->
            %{
              id: item.id,
              product: product,
              quantity: item.quantity,
              status: item.status,
              order: order
            }
          end)

        {day, product, production_items}
      end)
    end)
  end

  defp prepare_materials_requirements(socket, days_range) do
    raw_materials_data = load_materials_requirements(socket, days_range)

    Enum.map(raw_materials_data, fn {material, quantities} ->
      total_quantity = total_material_quantity(quantities)
      {balance_cells, final_balance} = calculate_material_balances(material, quantities)

      {material,
       %{
         quantities: quantities,
         total_quantity: total_quantity,
         balance_cells: balance_cells,
         final_balance: final_balance
       }}
    end)
  end

  defp calculate_material_balances(material, quantities) do
    initial_balance = material.current_stock || Decimal.new(0)

    Enum.map_reduce(quantities, initial_balance, fn {day_quantity, _day}, acc_balance ->
      current_balance = acc_balance
      new_balance = Decimal.sub(acc_balance, day_quantity)
      {current_balance, new_balance}
    end)
  end

  defp load_materials_requirements(socket, days_range) do
    start_date =
      days_range |> List.first() |> DateTime.new!(~T[00:00:00], socket.assigns.time_zone)

    end_date = days_range |> List.last() |> DateTime.new!(~T[23:59:59], socket.assigns.time_zone)

    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: start_date,
          delivery_date_end: end_date
        },
        load: [
          :items,
          items: [
            product: [:recipe, recipe: [components: [material: [:current_stock, :unit, :sku]]]]
          ]
        ]
      )

    # Pre-create a map with zero quantities for all days to avoid filtering later
    days_map = Map.new(days_range, fn day -> {day, Decimal.new(0)} end)

    # First pass: collect materials with quantities by day
    materials_map =
      for order <- orders,
          item <- order.items,
          recipe = item.product.recipe,
          recipe != nil,
          component <- recipe.components,
          reduce: %{} do
        acc ->
          day = DateTime.to_date(order.delivery_date)
          material = component.material
          quantity_needed = Decimal.mult(component.quantity, item.quantity)

          material_days = Map.get(acc, material, days_map)
          current_qty = Map.get(material_days, day, Decimal.new(0))
          updated_qty = Decimal.add(current_qty, quantity_needed)

          Map.put(acc, material, Map.put(material_days, day, updated_qty))
      end

    # Convert to the expected output format
    materials_map
    |> Enum.map(fn {material, days_with_quantities} ->
      quantities_by_day =
        Enum.map(days_range, fn day ->
          {Map.get(days_with_quantities, day, Decimal.new(0)), day}
        end)

      {material, quantities_by_day}
    end)
    |> Enum.sort_by(fn {material, _} -> material.name end)
  end

  defp get_items_for_day(day, production_items) do
    day_items =
      Enum.filter(production_items, fn {item_day, _, _} ->
        Date.compare(item_day, day) == :eq
      end)

    day_items
    |> Enum.group_by(
      fn {_, product, _} -> product end,
      fn {_, _, items} -> items end
    )
    |> Enum.map(fn {product, grouped_items} ->
      {product, List.flatten(grouped_items)}
    end)
  end

  defp get_product_items_for_day(day, product, production_items) do
    production_items
    |> Enum.filter(fn {item_day, item_product, _} ->
      Date.compare(item_day, day) == :eq && item_product.id == product.id
    end)
    |> Enum.flat_map(fn {_, _, items} -> items end)
  end

  defp find_product(_socket, product_id) do
    Catalog.get_product_by_id!(product_id)
  end

  defp total_quantity(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc -> Decimal.add(acc, item.quantity) end)
  end

  defp total_material_quantity(day_quantities) do
    Enum.reduce(day_quantities, Decimal.new(0), fn {quantity, _}, acc ->
      Decimal.add(acc, quantity)
    end)
  end

  defp find_material(_socket, material_id) do
    Inventory.get_material_by_id!(material_id)
  end

  defp get_material_day_info(socket, material, date) do
    with {_, material_data} <-
           Enum.find(socket.assigns.materials_requirements, fn {m, _} -> m.id == material.id end),
         day_index when not is_nil(day_index) <-
           Enum.find_index(material_data.quantities, fn {_, d} -> Date.compare(d, date) == :eq end) do
      day_quantity = elem(Enum.at(material_data.quantities, day_index), 0)
      day_balance = Enum.at(material_data.balance_cells, day_index)
      {day_quantity, day_balance}
    else
      _ -> {Decimal.new(0), Decimal.new(0)}
    end
  end

  defp get_material_usage_details(socket, material, date) do
    material_id = material.id

    start_datetime = DateTime.new!(date, ~T[00:00:00], socket.assigns.time_zone)
    end_datetime = DateTime.new!(date, ~T[23:59:59], socket.assigns.time_zone)

    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: start_datetime,
          delivery_date_end: end_datetime
        },
        load: [
          :reference,
          :items,
          items: [
            :quantity,
            product: [:name, :recipe, recipe: [components: [material: [:id, :unit]]]]
          ]
        ]
      )

    order_items_using_material =
      for order <- orders,
          item <- order.items,
          item.product.recipe != nil,
          component <- item.product.recipe.components,
          component.material.id == material_id do
        material_quantity = Decimal.mult(component.quantity, item.quantity)

        %{
          order: %{reference: order.reference},
          product: item.product,
          quantity: material_quantity
        }
      end

    order_items_using_material
    |> Enum.group_by(& &1.product)
    |> Enum.map(fn {product, items} ->
      total_quantity =
        Enum.reduce(items, Decimal.new(0), &Decimal.add(&1.quantity, &2))

      {product, %{total_quantity: total_quantity, order_items: items}}
    end)
    |> Enum.sort_by(fn {product, _} -> product.name end)
  end

  defp page_title(:schedule), do: "Plan: Production Planner"
  defp page_title(:materials), do: "Plan: Inventory Forecast"
  defp page_title(_), do: "Plan"

  defp progress_by_status(items, status) do
    zero = Decimal.new(0)
    hundred = Decimal.new(100)

    {status_quantity, total_quantity} =
      Enum.reduce(items, {zero, zero}, fn item, {status_acc, total_acc} ->
        total = Decimal.add(total_acc, item.quantity)

        status_qty =
          if item.status == status, do: Decimal.add(status_acc, item.quantity), else: status_acc

        {status_qty, total}
      end)

    case Decimal.compare(total_quantity, zero) do
      :gt ->
        status_quantity
        |> Decimal.div(total_quantity)
        |> Decimal.mult(hundred)
        |> Decimal.to_float()
        |> trunc()

      _ ->
        0
    end
  end
end
