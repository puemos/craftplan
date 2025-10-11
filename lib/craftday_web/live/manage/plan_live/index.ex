defmodule CraftdayWeb.PlanLive.Index do
  @moduledoc false
  use CraftdayWeb, :live_view

  alias Craftday.Catalog
  alias Craftday.Inventory
  alias Craftday.Orders
  alias Craftday.Orders.Consumption

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Production" path={~p"/manage/production"} current?={true} />
      </.breadcrumb>
      <:actions>
        <.link navigate={~p"/manage/production/make_sheet"}>
          <.button>Make Sheet</.button>
        </.link>
      </:actions>
    </.header>

    <.tabs id="production-tabs">
      <:tab
        label="Overview"
        path={~p"/manage/production"}
        selected?={@live_action == :index}
      >
        <div class="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <.stat_card
            title="Over‑Capacity Days"
            value={@week_metrics.over_capacity_days}
            description="This week"
          />
          <.stat_card
            title="Days > Order Cap"
            value={@week_metrics.over_order_capacity_days}
            description="This week"
          />
          <.stat_card
            title="Shortage Days"
            value={@week_metrics.material_shortage_days}
            description="Forecast"
          />
          <.stat_card title="Orders Today" value={@week_metrics.orders_today} description="Scheduled" />
          <.stat_card
            title="Outstanding Today"
            value={@week_metrics.outstanding_today}
            description="Not completed"
          />
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div>
            <h3 class="mb-2 text-sm font-medium text-stone-600">Over‑Capacity Details</h3>
            <div class="rounded border border-stone-200 bg-white">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="p-0 pr-6 pb-2">Day</th>
                    <th class="p-0 pr-6 pb-2">Product</th>
                    <th class="p-0 pr-6 pb-2">Scheduled</th>
                    <th class="p-0 pr-6 pb-2">Max</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-200 text-sm leading-6 text-stone-700">
                  <tr :for={row <- @overview_tables.over_capacity}>
                    <td class="p-0 py-2 pr-6">{Calendar.strftime(row.day, "%a %d")}</td>
                    <td class="p-0 py-2 pr-6">{row.product.name}</td>
                    <td class="p-0 py-2 pr-6">{row.qty}</td>
                    <td class="p-0 py-2 pr-6">{row.max}</td>
                  </tr>
                  <tr :if={Enum.empty?(@overview_tables.over_capacity)}>
                    <td colspan="4" class="py-6 text-center text-stone-500">No items</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div>
            <h3 class="mb-2 text-sm font-medium text-stone-600">Days Over Order Capacity</h3>
            <div class="rounded border border-stone-200 bg-white">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="p-0 pr-6 pb-2">Day</th>
                    <th class="p-0 pr-6 pb-2">Orders</th>
                    <th class="p-0 pr-6 pb-2">Cap</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-200 text-sm leading-6 text-stone-700">
                  <tr :for={row <- @overview_tables.over_order_capacity}>
                    <td class="p-0 py-2 pr-6">{Calendar.strftime(row.day, "%a %d")}</td>
                    <td class="p-0 py-2 pr-6">{row.count}</td>
                    <td class="p-0 py-2 pr-6">{row.cap}</td>
                  </tr>
                  <tr :if={Enum.empty?(@overview_tables.over_order_capacity)}>
                    <td colspan="3" class="py-6 text-center text-stone-500">No items</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="lg:col-span-2">
            <h3 class="mb-2 text-sm font-medium text-stone-600">Material Shortages</h3>
            <div class="rounded border border-stone-200 bg-white">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="p-0 pr-6 pb-2">Day</th>
                    <th class="p-0 pr-6 pb-2">Material</th>
                    <th class="p-0 pr-6 pb-2">Required</th>
                    <th class="p-0 pr-6 pb-2">Opening</th>
                    <th class="p-0 pr-6 pb-2">End Balance</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-200 text-sm leading-6 text-stone-700">
                  <tr :for={row <- @overview_tables.shortage}>
                    <td class="p-0 py-2 pr-6">{Calendar.strftime(row.day, "%a %d")}</td>
                    <td class="p-0 py-2 pr-6">{row.material.name}</td>
                    <td class="p-0 py-2 pr-6">{format_amount(row.material.unit, row.required)}</td>
                    <td class="p-0 py-2 pr-6">{format_amount(row.material.unit, row.opening)}</td>
                    <td class="p-0 py-2 pr-6">{format_amount(row.material.unit, row.ending)}</td>
                  </tr>
                  <tr :if={Enum.empty?(@overview_tables.shortage)}>
                    <td colspan="5" class="py-6 text-center text-stone-500">No items</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div>
            <h3 class="mb-2 text-sm font-medium text-stone-600">Orders Today</h3>
            <div class="rounded border border-stone-200 bg-white">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="p-0 pr-6 pb-2">Reference</th>
                    <th class="p-0 pr-6 pb-2">Customer</th>
                    <th class="p-0 pr-6 pb-2">Total</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-200 text-sm leading-6 text-stone-700">
                  <tr :for={row <- @overview_tables.orders_today}>
                    <td class="p-0 py-2 pr-6">
                      <.kbd>{row.reference}</.kbd>
                    </td>
                    <td class="p-0 py-2 pr-6">{row.customer}</td>
                    <td class="p-0 py-2 pr-6">{format_money(@settings.currency, row.total)}</td>
                  </tr>
                  <tr :if={Enum.empty?(@overview_tables.orders_today)}>
                    <td colspan="3" class="py-6 text-center text-stone-500">No items</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div>
            <h3 class="mb-2 text-sm font-medium text-stone-600">Outstanding Today</h3>
            <div class="rounded border border-stone-200 bg-white">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th class="p-0 pr-6 pb-2">Product</th>
                    <th class="p-0 pr-6 pb-2">Todo Qty</th>
                    <th class="p-0 pr-6 pb-2">In Progress Qty</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-200 text-sm leading-6 text-stone-700">
                  <tr :for={row <- @overview_tables.outstanding_today}>
                    <td class="p-0 py-2 pr-6">{row.product.name}</td>
                    <td class="p-0 py-2 pr-6">{row.todo}</td>
                    <td class="p-0 py-2 pr-6">{row.in_progress}</td>
                  </tr>
                  <tr :if={Enum.empty?(@overview_tables.outstanding_today)}>
                    <td colspan="3" class="py-6 text-center text-stone-500">No items</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </:tab>

      <:tab
        label="Schedule"
        path={~p"/manage/production/schedule"}
        selected?={@live_action == :schedule}
      >
        <div class="mt-4">
          <div class="mt-8">
            <div
              id="controls"
              class="border-gray-200/70 flex items-center justify-between border-b pb-4"
            >
              <div></div>
              <div class="flex items-center space-x-4">
                <div class="mr-2 hidden items-center space-x-1 sm:flex">
                  <button
                    phx-click="set_schedule_view"
                    phx-value-view="week"
                    class={[
                      "border px-2 py-1 text-xs",
                      (@schedule_view == :week && "border-stone-300 bg-stone-200") ||
                        "border-stone-300 bg-white"
                    ]}
                  >
                    Week
                  </button>
                  <button
                    phx-click="set_schedule_view"
                    phx-value-view="day"
                    class={[
                      "border px-2 py-1 text-xs",
                      (@schedule_view == :day && "border-stone-300 bg-stone-200") ||
                        "border-stone-300 bg-white"
                    ]}
                  >
                    Day
                  </button>
                </div>
                <div class="flex items-center">
                  <button
                    phx-click="previous_week"
                    size={:sm}
                    class="px-[6px] cursor-pointer rounded-l-md border border-gray-300 bg-white py-1 hover:bg-gray-50"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M11 17l-5-5m0 0l5-5m-5 5h12"
                      />
                    </svg>
                  </button>
                  <button
                    phx-click="today"
                    size={:sm}
                    variant={:outline}
                    class="flex cursor-pointer items-center border-y border-gray-300 bg-white px-3 py-1 text-xs font-medium hover:bg-gray-50 disabled:cursor-default disabled:bg-gray-100 disabled:text-gray-400"
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
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M13 7l5 5m0 0l-5 5m5-5H6"
                      />
                    </svg>
                  </button>
                </div>
              </div>

              <div class="absolute left-1/2 -translate-x-1/2 transform">
                <span class="font-medium text-stone-700">
                  {Calendar.strftime(List.first(@days_range), "%B %Y")}
                </span>
              </div>
            </div>
            <div class="min-w-[1000px]">
              <table class="w-full table-fixed border-collapse">
                <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
                  <tr>
                    <th
                      :for={
                        {day, index} <-
                          Enum.with_index(
                            @days_range
                            |> Enum.take((@schedule_view == :day && 1) || 7)
                          )
                      }
                      class={
                        [
                          "w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 font-normal last:border-r-0",
                          index > 0 && "pl-4",
                          is_today?(day) && "border border-stone-300 bg-stone-200",
                          is_today?(Date.add(day, 1)) && "border-r border-r-stone-300"
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
                  </tr>
                </thead>
                <tbody>
                  <tr class="h-[60vh]">
                    <td
                      :for={
                        {day, index} <-
                          Enum.with_index(
                            @days_range
                            |> Enum.take((@schedule_view == :day && 1) || 7)
                          )
                      }
                      class={
                        [
                          "border-t border-t-stone-200",
                          index > 0 && "border-l",
                          index < 6 && "border-r",
                          is_today?(day) && "border border-stone-300 bg-stone-200",
                          is_today?(Date.add(day, 1)) && "border-r border-r-stone-300",
                          "min-h-[200px] w-1/7 overflow-hidden border-stone-200 p-2 align-top"
                        ]
                        |> Enum.filter(& &1)
                        |> Enum.join("  ")
                      }
                    >
                      <div class="h-full overflow-y-auto">
                        <div
                          :for={{product, items} <- get_items_for_day(day, @production_items)}
                          phx-click="view_details"
                          phx-value-date={Date.to_iso8601(day)}
                          phx-value-product={product.id}
                          class={[
                            "group mb-2 cursor-pointer border p-2",
                            capacity_cell_class(product, items),
                            "hover:bg-stone-100"
                          ]}
                        >
                          <div class="mb-1.5 flex items-center justify-between gap-2">
                            <span class="truncate text-sm font-medium" title={product.name}>
                              {product.name}
                            </span>
                            <.badge
                              :if={capacity_status(product, items) == :over}
                              text="Over capacity"
                            />
                          </div>
                          <div class="mt-1.5 flex items-center justify-between text-xs text-stone-500">
                            <span>
                              {format_amount(:piece, total_quantity(items))}
                              <span
                                :if={(product.max_daily_quantity || 0) > 0}
                                class="ml-1 text-stone-400"
                              >
                                / {product.max_daily_quantity}
                              </span>
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
      </:tab>
    </.tabs>

    <.modal
      :if={@live_action == :make_sheet}
      id="make-sheet-modal"
      show
      title={"Make Sheet — #{format_day_name(@today)} #{format_short_date(@today, @time_zone)}"}
      on_cancel={JS.patch(~p"/manage/production/schedule")}
      fullscreen
    >
      <div class="px-4 py-2 print:p-0">
        <div class="mb-3 flex items-center justify-between print:mb-2">
          <div class="text-lg font-medium print:text-base">Today's Production</div>
          <div class="space-x-2 print:hidden">
            <.button phx-click="consume_all_today">Consume All Completed</.button>
            <.button variant={:outline} onclick="window.print()">Print</.button>
          </div>
        </div>
        <div class="rounded border border-stone-300 bg-white print:border-black">
          <.table id="make-sheet" no_margin rows={make_sheet_rows(@production_items, @today)}>
            <:col :let={row} label="Product">{row.product.name}</:col>
            <:col :let={row} label="Total Qty">{row.total}</:col>
            <:col :let={row} label="Completed">{row.completed}</:col>
          </.table>
        </div>
      </div>
    </.modal>

    <.modal
      :if={@selected_date && @selected_product}
      id="product-details-modal"
      show
      title={"#{@selected_product.name} for #{format_day_name(@selected_date)} #{format_short_date(@selected_date, @time_zone)}"}
      on_cancel={JS.push("close_modal")}
    >
      <div class="py-4">
        <div
          :if={@pending_consumption_item_id}
          class="mb-4 rounded border border-stone-200 bg-amber-50 p-4"
        >
          <div class="mb-2 text-base font-medium text-stone-900">
            Would you like to update materials stock?
          </div>
          <p class="mb-3 text-sm text-stone-700">
            Completing this item will consume materials according to the product recipe. Review the quantities below and confirm.
          </p>
          <.table id="consumption-recap" rows={@pending_consumption_recap}>
            <:col :let={row} label="Material">{row.material.name}</:col>
            <:col :let={row} label="Required">{format_amount(row.material.unit, row.required)}</:col>
            <:col :let={row} label="Current Stock">
              {format_amount(row.material.unit, row.current_stock || Decimal.new(0))}
            </:col>
          </.table>
          <div class="mt-3 flex space-x-2">
            <.button phx-click="confirm_consume">Consume Now</.button>
            <.button variant={:outline} phx-click="cancel_consume">Not Now</.button>
          </div>
        </div>

        <div :if={@selected_details} class="space-y-4">
          <.table id="product-orders" rows={@selected_details}>
            <:col :let={item} label="Reference">
              <.link navigate={~p"/manage/orders/#{item.order.reference}/items"}>
                <.kbd>{format_reference(item.order.reference)}</.kbd>
              </.link>
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
    days_range = generate_current_week_range()

    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(socket, days_range, production_items, materials_requirements)
      )

    socket =
      socket
      |> assign(:today, today)
      |> assign(:days_range, days_range)
      |> assign(:production_items, production_items)
      |> assign(:materials_requirements, materials_requirements)
      |> assign(:week_metrics, week_metrics)
      |> assign(:overview_tables, overview_tables)
      |> assign(:schedule_view, :week)
      |> assign(:selected_date, nil)
      |> assign(:selected_product, nil)
      |> assign(:selected_details, nil)
      |> assign(:selected_material_date, nil)
      |> assign(:selected_material, nil)
      |> assign(:material_details, nil)
      |> assign(:material_day_quantity, nil)
      |> assign(:material_day_balance, nil)
      |> assign(:pending_consumption_item_id, nil)
      |> assign(:pending_consumption_recap, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, assign(socket, :page_title, page_title(socket.assigns.live_action))}
  end

  @impl true
  def handle_event(
        "view_material_details",
        %{"date" => date_str, "material" => material_id},
        socket
      ) do
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
    step = if socket.assigns.schedule_view == :day, do: 1, else: 7
    monday = List.first(socket.assigns.days_range)
    new_start = Date.add(monday, -step)
    days_range = generate_week_range(new_start)
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(socket, days_range, production_items, materials_requirements)
      )

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)
     |> assign(:week_metrics, week_metrics)
     |> assign(:overview_tables, overview_tables)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    step = if socket.assigns.schedule_view == :day, do: 1, else: 7
    monday = List.first(socket.assigns.days_range)
    new_start = Date.add(monday, step)
    days_range = generate_week_range(new_start)
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(socket, days_range, production_items, materials_requirements)
      )

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)
     |> assign(:week_metrics, week_metrics)
     |> assign(:overview_tables, overview_tables)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    days_range = generate_current_week_range()
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(socket, days_range, production_items, materials_requirements)
      )

    {:noreply,
     socket
     |> assign(:today, Date.utc_today())
     |> assign(:days_range, days_range)
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)
     |> assign(:week_metrics, week_metrics)
     |> assign(:overview_tables, overview_tables)}
  end

  @impl true
  def handle_event("set_schedule_view", %{"view" => view}, socket) do
    schedule_view = if view == "day", do: :day, else: :week
    {:noreply, assign(socket, :schedule_view, schedule_view)}
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

    case Orders.update_item(order_item, %{status: String.to_atom(status)},
           actor: socket.assigns.current_user
         ) do
      {:ok, updated_item} ->
        days_range = socket.assigns.days_range
        production_items = load_production_items(socket, days_range)
        materials_requirements = prepare_materials_requirements(socket, days_range)

        week_metrics =
          compute_week_metrics(socket, days_range, production_items, materials_requirements)

        selected_details =
          if socket.assigns.selected_product do
            get_product_items_for_day(
              socket.assigns.selected_date,
              socket.assigns.selected_product,
              production_items
            )
          end

        socket =
          socket
          |> assign(:production_items, production_items)
          |> assign(:materials_requirements, materials_requirements)
          |> assign(:week_metrics, week_metrics)
          |> assign(:selected_details, selected_details)
          |> put_flash(:info, "Item status updated")

        # If just marked completed, prepare confirmation recap
        socket =
          if String.to_atom(status) == :done do
            item =
              Orders.get_order_item_by_id!(updated_item.id,
                load: [
                  :quantity,
                  product: [recipe: [components: [material: [:name, :unit, :current_stock]]]]
                ]
              )

            recap =
              case item.product.recipe do
                nil ->
                  []

                recipe ->
                  Enum.map(recipe.components, fn c ->
                    %{
                      material: c.material,
                      required: Decimal.mult(c.quantity, item.quantity),
                      current_stock: c.material.current_stock
                    }
                  end)
              end

            socket
            |> assign(:pending_consumption_item_id, updated_item.id)
            |> assign(:pending_consumption_recap, recap)
          else
            socket
          end

        overview_tables =
          compute_overview_tables_from(
            build_overview_assigns(
              socket,
              days_range,
              production_items,
              materials_requirements
            )
          )

        {:noreply, assign(socket, :overview_tables, overview_tables)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("consume_item", %{"item_id" => id}, socket) do
    _ = Consumption.consume_item(id, actor: socket.assigns.current_user)

    days_range = socket.assigns.days_range
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    selected_details =
      if socket.assigns.selected_product do
        get_product_items_for_day(
          socket.assigns.selected_date,
          socket.assigns.selected_product,
          production_items
        )
      end

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(
          socket,
          days_range,
          production_items,
          materials_requirements
        )
      )

    {:noreply,
     socket
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)
     |> assign(:week_metrics, week_metrics)
     |> assign(:overview_tables, overview_tables)
     |> assign(:selected_details, selected_details)
     |> assign(:pending_consumption_item_id, nil)
     |> assign(:pending_consumption_recap, [])
     |> put_flash(:info, "Materials consumed")}
  end

  @impl true
  def handle_event("confirm_consume", _params, socket) do
    if socket.assigns.pending_consumption_item_id do
      _ =
        Consumption.consume_item(socket.assigns.pending_consumption_item_id,
          actor: socket.assigns.current_user
        )

      days_range = socket.assigns.days_range
      production_items = load_production_items(socket, days_range)
      materials_requirements = prepare_materials_requirements(socket, days_range)

      week_metrics =
        compute_week_metrics(socket, days_range, production_items, materials_requirements)

      selected_details =
        if socket.assigns.selected_product do
          get_product_items_for_day(
            socket.assigns.selected_date,
            socket.assigns.selected_product,
            production_items
          )
        end

      overview_tables =
        compute_overview_tables_from(
          build_overview_assigns(
            socket,
            days_range,
            production_items,
            materials_requirements
          )
        )

      {:noreply,
       socket
       |> assign(:production_items, production_items)
       |> assign(:materials_requirements, materials_requirements)
       |> assign(:week_metrics, week_metrics)
       |> assign(:overview_tables, overview_tables)
       |> assign(:selected_details, selected_details)
       |> assign(:pending_consumption_item_id, nil)
       |> assign(:pending_consumption_recap, [])
       |> put_flash(:info, "Materials consumed")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("consume_all_today", _params, socket) do
    today = socket.assigns.today
    items_by_product = get_items_for_day(today, socket.assigns.production_items)

    items_by_product
    |> Enum.flat_map(fn {_product, items} -> items end)
    |> Enum.filter(fn item -> item.status == :done and is_nil(item.consumed_at) end)
    |> Enum.each(fn item ->
      _ = Consumption.consume_item(item.id, actor: socket.assigns.current_user)
    end)

    # refresh
    days_range = socket.assigns.days_range
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    overview_tables =
      compute_overview_tables_from(
        build_overview_assigns(
          socket,
          days_range,
          production_items,
          materials_requirements
        )
      )

    {:noreply,
     socket
     |> assign(:production_items, production_items)
     |> assign(:materials_requirements, materials_requirements)
     |> assign(:overview_tables, overview_tables)
     |> put_flash(:info, "Consumed all completed items for today")}
  end

  @impl true
  def handle_event("cancel_consume", _params, socket) do
    {:noreply,
     socket
     |> assign(:pending_consumption_item_id, nil)
     |> assign(:pending_consumption_recap, [])}
  end

  defp generate_current_week_range do
    today = Date.utc_today()
    # Get the beginning of week (Monday)
    monday = Date.add(today, -(Date.day_of_week(today) - 1))
    Enum.map(0..6, &Date.add(monday, &1))
  end

  defp generate_week_range(start_date, days \\ 7) do
    Enum.map(0..(days - 1), fn offset -> Date.add(start_date, offset) end)
  end

  defp format_day_name(date) do
    day_names = ~w(Mon Tue Wed Thu Fri Sat Sun)

    Enum.at(day_names, Date.day_of_week(date) - 1)
  end

  defp load_production_items(socket, days_range) do
    orders =
      Orders.list_orders!(
        %{
          delivery_date_start:
            days_range |> List.first() |> DateTime.new!(~T[00:00:00], socket.assigns.time_zone),
          delivery_date_end:
            days_range |> List.last() |> DateTime.new!(~T[23:59:59], socket.assigns.time_zone)
        },
        load: [
          :items,
          :status,
          customer: [:full_name],
          items: [:consumed_at, product: [:name, :max_daily_quantity]]
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
              consumed_at: item.consumed_at,
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

  defp make_sheet_rows(production_items, day) do
    production_items
    |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, day) == :eq end)
    |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
    |> Enum.map(fn {product, groups} ->
      items = List.flatten(groups)
      total = total_quantity(items)

      completed =
        items
        |> Enum.filter(&(&1.status == :done))
        |> total_quantity()

      %{product: product, total: total, completed: completed}
    end)
    |> Enum.sort_by(fn row -> row.product.name end)
  end

  defp capacity_status(product, items) do
    max = product.max_daily_quantity || 0

    if max <= 0 do
      :ok
    else
      qty = total_quantity(items)

      case Decimal.compare(qty, Decimal.new(max)) do
        :gt -> :over
        :eq -> :limit
        _ -> :ok
      end
    end
  end

  defp capacity_cell_class(product, items) do
    case capacity_status(product, items) do
      :over -> "border-rose-300 bg-rose-50"
      :limit -> "border-amber-300 bg-amber-50"
      :ok -> "border-stone-200 bg-white"
    end
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

  defp page_title(:schedule), do: "Plan: Schedule"
  defp page_title(:materials), do: "Plan: Inventory Forecast"
  defp page_title(:make_sheet), do: "Plan: Make Sheet"
  defp page_title(_), do: "Plan: Overview"

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

  defp compute_week_metrics(socket, days_range, production_items, materials_requirements) do
    # Over‑capacity days (any product/day exceeds max)
    over_capacity_days =
      Enum.count(days_range, fn day ->
        production_items
        |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, day) == :eq end)
        |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
        |> Enum.any?(fn {product, groups} ->
          max = product.max_daily_quantity || 0

          if max <= 0 do
            false
          else
            qty = groups |> List.flatten() |> total_quantity()
            Decimal.compare(qty, Decimal.new(max)) == :gt
          end
        end)
      end)

    # Over daily capacity by orders count (if configured)
    tz = socket.assigns.time_zone
    start_dt = days_range |> List.first() |> DateTime.new!(~T[00:00:00], tz)
    end_dt = days_range |> List.last() |> DateTime.new!(~T[23:59:59], tz)

    orders =
      Orders.list_orders!(%{delivery_date_start: start_dt, delivery_date_end: end_dt})

    orders_by_day = Enum.group_by(orders, fn o -> DateTime.to_date(o.delivery_date) end)
    cap = socket.assigns.settings.daily_capacity || 0

    over_order_capacity_days =
      if cap > 0 do
        Enum.count(days_range, fn day -> length(Map.get(orders_by_day, day, [])) > cap end)
      else
        0
      end

    # Materials shortage days (any material balance < 0 on any day)
    material_shortage_days =
      Enum.count(days_range, fn day ->
        Enum.any?(materials_requirements, fn {_material, data} ->
          # iterate running balance and detect if new balance goes negative on this day
          case Enum.find_index(data.quantities, fn {_, d} -> Date.compare(d, day) == :eq end) do
            nil ->
              false

            idx ->
              # simulate to index
              {balance, _} =
                Enum.reduce(Enum.take(data.quantities, idx + 1), {Decimal.new(0), nil}, fn {q, _d},
                                                                                           {_bal,
                                                                                            _} ->
                  # We need initial stock; balance_cells[idx] holds opening balance for that day
                  opening =
                    Enum.at(
                      data.balance_cells,
                      Enum.count(Enum.take(data.quantities, idx + 1)) - 1
                    ) || Decimal.new(0)

                  new_bal = Decimal.sub(opening, q)
                  {new_bal, nil}
                end)

              Decimal.compare(balance, Decimal.new(0)) == :lt
          end
        end)
      end)

    # Today metrics
    today = Date.utc_today()
    orders_today = length(Map.get(orders_by_day, today, []))

    outstanding_today =
      production_items
      |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, today) == :eq end)
      |> Enum.flat_map(fn {_d, _p, items} -> items end)
      |> Enum.filter(&(&1.status != :done))
      |> total_quantity()

    %{
      over_capacity_days: over_capacity_days,
      over_order_capacity_days: over_order_capacity_days,
      material_shortage_days: material_shortage_days,
      orders_today: orders_today,
      outstanding_today: outstanding_today
    }
  end

  defp compute_overview_tables_from(assigns) do
    # Over‑capacity days (any product/day exceeds max)
    over_capacity_rows =
      Enum.flat_map(assigns.days_range, fn day ->
        assigns.production_items
        |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, day) == :eq end)
        |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
        |> Enum.flat_map(fn {product, groups} ->
          max = product.max_daily_quantity || 0

          if max > 0 do
            qty = groups |> List.flatten() |> total_quantity()

            if Decimal.compare(qty, Decimal.new(max)) == :gt do
              [%{day: day, product: product, qty: qty, max: max}]
            else
              []
            end
          else
            []
          end
        end)
      end)

    # Over daily capacity by orders count (if configured)
    tz = assigns.time_zone
    cap = assigns.settings.daily_capacity || 0

    over_order_capacity_rows =
      if cap > 0 do
        start_dt = assigns.days_range |> List.first() |> DateTime.new!(~T[00:00:00], tz)
        end_dt = assigns.days_range |> List.last() |> DateTime.new!(~T[23:59:59], tz)

        orders =
          Orders.list_orders!(%{
            delivery_date_start: start_dt,
            delivery_date_end: end_dt
          })

        orders_by_day = Enum.group_by(orders, fn o -> DateTime.to_date(o.delivery_date) end)

        Enum.flat_map(assigns.days_range, fn day ->
          cnt = length(Map.get(orders_by_day, day, []))
          if cnt > cap, do: [%{day: day, count: cnt, cap: cap}], else: []
        end)
      else
        []
      end

    # Materials shortage days (any material balance < 0 on any day)
    shortage_rows =
      assigns.materials_requirements
      |> Enum.flat_map(fn {material, data} ->
        data.quantities
        |> Enum.with_index()
        |> Enum.flat_map(fn {{day_quantity, day}, idx} ->
          opening = Enum.at(data.balance_cells, idx) || Decimal.new(0)
          ending = Decimal.sub(opening, day_quantity)

          if Decimal.compare(ending, Decimal.new(0)) == :lt do
            [
              %{
                day: day,
                material: material,
                required: day_quantity,
                opening: opening,
                ending: ending
              }
            ]
          else
            []
          end
        end)
      end)
      |> Enum.sort_by(fn r -> {r.day, r.material.name} end)

    # Orders today
    today = Date.utc_today()
    start_dt = DateTime.new!(today, ~T[00:00:00], tz)
    end_dt = DateTime.new!(today, ~T[23:59:59], tz)

    orders_today_rows =
      %{delivery_date_start: start_dt, delivery_date_end: end_dt}
      |> Orders.list_orders!(load: [:total_cost, :reference, customer: [:full_name]])
      |> Enum.map(fn o ->
        %{reference: o.reference, customer: o.customer.full_name, total: o.total_cost}
      end)

    # Outstanding today
    outstanding_today_rows =
      assigns.production_items
      |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, today) == :eq end)
      |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
      |> Enum.map(fn {product, groups} ->
        items = List.flatten(groups)
        todo = items |> Enum.filter(&(&1.status == :todo)) |> total_quantity()
        in_progress = items |> Enum.filter(&(&1.status == :in_progress)) |> total_quantity()
        %{product: product, todo: todo, in_progress: in_progress}
      end)
      |> Enum.sort_by(fn r -> r.product.name end)

    %{
      over_capacity: over_capacity_rows,
      over_order_capacity: over_order_capacity_rows,
      shortage: shortage_rows,
      orders_today: orders_today_rows,
      outstanding_today: outstanding_today_rows
    }
  end

  defp build_overview_assigns(socket, days_range, production_items, materials_requirements) do
    %{
      days_range: days_range,
      production_items: production_items,
      materials_requirements: materials_requirements,
      time_zone: socket.assigns.time_zone,
      settings: socket.assigns.settings
    }
  end
end
