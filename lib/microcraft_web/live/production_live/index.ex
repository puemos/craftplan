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
      <.tabs id="production-tabs">
        <:tab
          label="Production Planner"
          path={~p"/manage/plan/schedule"}
          selected?={@live_action in [:schedule, :index]}
        >
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
        </:tab>

        <:tab
          label="Inventory Forecast"
          path={~p"/manage/plan/materials"}
          selected?={@live_action == :materials}
        >
          <div class="mt-8 overflow-x-auto">
            <div class="min-w-[1000px]">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="w-1/7 border-r border-stone-200 p-0 pb-4 font-normal">
                      Material
                    </th>
                    <th
                      :for={{day, _index} <- Enum.with_index(@days_range |> Enum.take(7))}
                      class="w-1/7 border-r border-stone-200 p-0 pb-4 pl-4 font-normal last:border-r-0"
                    >
                      <div>{format_day_name(day)}</div>
                      <div>{format_short_date(day, @time_zone)}</div>
                    </th>
                    <th class="w-1/7 border-stone-200 p-0 pb-4 pl-4 font-normal">
                      Total
                    </th>
                  </tr>
                </thead>
                <tbody class="text-sm leading-6 text-stone-700">
                  <tr :for={{material, material_data} <- @materials_requirements}>
                    <td class="border-t border-r border-t-stone-200 py-2 pr-2 text-center font-medium">
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
                        "relative border-t border-r border-t-stone-200 p-2 text-center text-sm",
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
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@selected_material_date && @selected_material}
      id="material-details-modal"
      show
      on_cancel={JS.push("close_material_modal")}
    >
      <.header>
        {@selected_material.name} - {format_short_date(@selected_material_date, @time_zone)}
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
      </footer>
    </.modal>

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
              <span class="font-medium">{format_reference(item.order.reference)}</span>
            </:col>
            <:col :let={item} label="Quantity">
              <span class="text-sm">{item.quantity}x</span>
            </:col>
            <:col :let={item} label="Customer">
              <span class="text-sm">{item.order.customer.full_name}</span>
            </:col>
            <:col :let={item} label="Status">
              <.badge
                text={format_status(item.status)}
                colors={[
                  {item.status, "#{order_status_color(item.status)} #{order_status_bg(item.status)}"}
                ]}
              />
            </:col>
            <:action :let={item}>
              <.button
                :if={item.status == :todo}
                phx-click="update_item_status"
                phx-value-id={item.id}
                phx-value-status="in_progress"
                size={:sm}
                class="w-full justify-center"
              >
                Start Production
              </.button>

              <.button
                :if={item.status == :in_progress}
                phx-click="update_item_status"
                phx-value-id={item.id}
                phx-value-status="done"
                size={:sm}
                class="w-full justify-center"
              >
                Complete
              </.button>

              <.badge :if={item.status == :done} text="Completed ✓" />
            </:action>
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
    socket = assign(socket, :page_title, page_title(socket.assigns.live_action))

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_material_details", %{"date" => date_str, "material" => material_id}, socket) do
    date = Date.from_iso8601!(date_str)
    material = find_material(socket, material_id)

    # Get material day quantity
    {day_quantity, day_balance} = get_material_day_info(socket, material, date)

    # Get details of orders/products using this material on this day
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
    # Move the date range back by 7 days
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
    # Move the date range forward by 7 days
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
    # Reset to current week
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
  def handle_event("update_item_status", %{"id" => id, "status" => status}, socket) do
    order_item = Orders.get_order_item_by_id!(id, actor: socket.assigns.current_user)

    case Orders.update_item(order_item, %{status: String.to_atom(status)}, actor: socket.assigns.current_user) do
      {:ok, _order_item} ->
        days_range = socket.assigns.days_range
        production_items = load_production_items(socket, days_range)
        materials_requirements = prepare_materials_requirements(socket, days_range)

        # If we have a selected product, refresh its details too
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

      {:error, e} ->
        dbg(e)
        {:noreply, socket}
    end
  end

  # Helper functions

  defp generate_week_range(start_date) do
    Enum.map(0..6, fn day_offset ->
      Date.add(start_date, day_offset)
    end)
  end

  defp is_weekend?(date) do
    day_of_week = Date.day_of_week(date)
    # Saturday or Sunday
    day_of_week == 6 || day_of_week == 7
  end

  defp is_today?(date) do
    Date.compare(date, Date.utc_today()) == :eq
  end

  defp format_day_name(date) do
    # Return abbreviated day name: Mon, Tue, etc.
    day_names = ~w(Mon Tue Wed Thu Fri Sat Sun)
    day_of_week = Date.day_of_week(date)

    if is_today?(date) do
      "Today"
    else
      Enum.at(day_names, day_of_week - 1)
    end
  end

  defp format_status(status) do
    case status do
      :todo -> "To Do"
      :in_progress -> "In Progress"
      :done -> "Completed"
      _ -> "Unknown"
    end
  end

  defp load_production_items(socket, days_range) do
    # Load actual production items for the given date range

    # Get all orders that need to be delivered in the date range
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

    # Convert orders to production items grouped by day and product
    Enum.flat_map(orders, fn order ->
      # Get the day from the order's delivery date
      day = DateTime.to_date(order.delivery_date)

      # Group order items by product
      order.items
      |> Enum.group_by(fn item -> item.product end)
      |> Enum.map(fn {product, items} ->
        # Create production items for each product
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
    # Get raw material requirements data
    raw_materials_data = load_materials_requirements(socket, days_range)

    # Process each material to include balance calculations
    Enum.map(raw_materials_data, fn {material, quantities} ->
      # Calculate total material quantity
      total_quantity = total_material_quantity(quantities)

      # Calculate balance cells and final balance
      {balance_cells, final_balance} = calculate_material_balances(material, quantities)

      # Return processed data
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
    # Initialize running balance with current stock or 0
    initial_balance = material.current_stock || Decimal.new(0)

    # Calculate balance cells
    {balance_cells, final_bal} =
      Enum.map_reduce(quantities, initial_balance, fn {day_quantity, _day}, acc_balance ->
        # First return the current balance before subtraction
        current_balance = acc_balance
        # Calculate new running balance by subtracting the day's quantity
        new_balance = Decimal.sub(acc_balance, day_quantity)
        # Return current balance as cell value and new balance as accumulator
        {current_balance, new_balance}
      end)

    # Return balance cells and final balance
    {balance_cells, final_bal}
  end

  defp load_materials_requirements(socket, days_range) do
    # Get all orders that need to be delivered in the date range
    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: days_range |> List.first() |> DateTime.new!(~T[00:00:00], socket.assigns.time_zone),
          delivery_date_end: days_range |> List.last() |> DateTime.new!(~T[23:59:59], socket.assigns.time_zone)
        },
        load: [
          :items,
          items: [
            product: [:recipe, recipe: [components: [material: [:current_stock, :unit, :sku]]]]
          ]
        ]
      )

    # Calculate materials needed for each day
    materials_by_day =
      Enum.flat_map(orders, fn order ->
        day = DateTime.to_date(order.delivery_date)

        # Get product items for this order
        Enum.flat_map(order.items, fn item ->
          # Get recipe for this product if available
          if item.product.recipe do
            # Calculate materials needed for this item
            Enum.map(item.product.recipe.components, fn component ->
              # Calculate quantity needed based on order quantity
              quantity_needed = Decimal.mult(component.quantity, item.quantity)

              # Return tuple of {day, material, quantity}
              {day, component.material, quantity_needed}
            end)
          else
            []
          end
        end)
      end)

    # Group materials by material and day
    materials_by_day
    |> Enum.group_by(
      fn {_, material, _} -> material end,
      fn {day, _, quantity} -> {day, quantity} end
    )
    |> Enum.map(fn {material, day_quantities} ->
      # Group quantities by day
      quantities_by_day =
        Enum.map(days_range, fn day ->
          # Find quantities for this day
          day_quantity =
            day_quantities
            |> Enum.filter(fn {qty_day, _} -> Date.compare(qty_day, day) == :eq end)
            |> Enum.reduce(Decimal.new(0), fn {_, qty}, acc -> Decimal.add(acc, qty) end)

          {day_quantity, day}
        end)

      {material, quantities_by_day}
    end)
    |> Enum.sort_by(fn {material, _} -> material.name end)
  end

  defp get_items_for_day(day, production_items) do
    # Filter items for the given day
    day_items =
      Enum.filter(production_items, fn {item_day, _, _} ->
        Date.compare(item_day, day) == :eq
      end)

    # Group items by product
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
    # Find the item for this specific product and day
    production_items
    |> Enum.filter(fn {item_day, item_product, _} ->
      Date.compare(item_day, day) == :eq && item_product.id == product.id
    end)
    |> Enum.flat_map(fn {_, _, items} -> items end)
  end

  defp find_product(_socket, product_id) do
    # Fetch the product from the database
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
    # Fetch the material from the database
    Inventory.get_material_by_id!(material_id)
  end

  defp get_material_day_info(socket, material, date) do
    # Find the material in the requirements data
    case Enum.find(socket.assigns.materials_requirements, fn {m, _} -> m.id == material.id end) do
      {_, material_data} ->
        # Find the day's quantity and balance
        day_index =
          Enum.find_index(material_data.quantities, fn {_, d} -> Date.compare(d, date) == :eq end)

        day_quantity = elem(Enum.at(material_data.quantities, day_index), 0)
        day_balance = Enum.at(material_data.balance_cells, day_index)
        {day_quantity, day_balance}

      _ ->
        {Decimal.new(0), Decimal.new(0)}
    end
  end

  defp get_material_usage_details(socket, material, date) do
    # Get all orders that need to be delivered on this date
    orders =
      Orders.list_orders!(
        %{
          delivery_date_start: DateTime.new!(date, ~T[00:00:00], socket.assigns.time_zone),
          delivery_date_end: DateTime.new!(date, ~T[23:59:59], socket.assigns.time_zone)
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

    # Filter orders for items using this material
    order_items_using_material =
      Enum.flat_map(orders, fn order ->
        # Get order items using this material
        items_using_material =
          Enum.filter(order.items, fn item ->
            # Check if this product uses the specified material
            if item.product.recipe do
              Enum.any?(item.product.recipe.components, fn component ->
                component.material.id == material.id
              end)
            else
              false
            end
          end)

        # Return item with order reference for context
        Enum.map(items_using_material, fn item ->
          # Calculate material quantity used
          material_quantity =
            if item.product.recipe do
              component =
                Enum.find(item.product.recipe.components, fn c -> c.material.id == material.id end)

              if component,
                do: Decimal.mult(component.quantity, item.quantity),
                else: Decimal.new(0)
            else
              Decimal.new(0)
            end

          %{
            order: %{reference: order.reference},
            product: item.product,
            quantity: material_quantity
          }
        end)
      end)

    # Group by product
    order_items_using_material
    |> Enum.group_by(
      fn item -> item.product end,
      fn item -> item end
    )
    |> Enum.map(fn {product, items} ->
      # Calculate total quantity for this product
      total_quantity =
        Enum.reduce(items, Decimal.new(0), fn item, acc ->
          Decimal.add(acc, item.quantity)
        end)

      {product, %{total_quantity: total_quantity, order_items: items}}
    end)
    |> Enum.sort_by(fn {product, _} -> product.name end)
  end

  defp page_title(:schedule), do: "Plan: Production Planner"
  defp page_title(:materials), do: "Plan: Inventory Forecast"
  defp page_title(_), do: "Plan"

  defp progress_by_status(items, status) do
    # Calculate total sum of quantities for all items
    total_quantity =
      Enum.reduce(items, Decimal.new(0), fn item, acc ->
        Decimal.add(acc, item.quantity)
      end)

    # Calculate sum of quantities for items with the given status
    status_quantity =
      Enum.reduce(items, Decimal.new(0), fn item, acc ->
        if item.status == status do
          Decimal.add(acc, item.quantity)
        else
          acc
        end
      end)

    # Calculate percentage based on quantities
    if Decimal.compare(total_quantity, Decimal.new(0)) == :gt do
      percentage =
        Decimal.to_float(Decimal.mult(Decimal.div(status_quantity, total_quantity), Decimal.new(100)))

      trunc(percentage)
    else
      0
    end
  end
end
