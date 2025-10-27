defmodule CraftplanWeb.PlanLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders
  alias Craftplan.Orders.Consumption
  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    first_schedule_day =
      assigns
      |> Map.get(:days_range)
      |> case do
        nil -> nil
        [] -> nil
        days -> List.first(days)
      end

    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)
      |> assign(:first_schedule_day, first_schedule_day)

    ~H"""
    <Page.page>
      <.header>
        Today at a glance
        <:subtitle>
          Production commitments, capacity pressure, and material risks for the current cycle.
        </:subtitle>
      </.header>
      <Page.two_column :if={@live_action == :index}>
        <:left>
          <Page.section>
            <Page.form_grid columns={2}>
              <Page.surface>
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Orders today</h3>
                    <p class="text-xs text-stone-500">
                      Deliveries scheduled for this production date.
                    </p>
                  </div>
                </:header>
                <.table
                  id="orders-today"
                  rows={@overview_tables.orders_today}
                  variant={:compact}
                  zebra
                  no_margin
                  row_click={fn row -> JS.navigate("/manage/orders/#{row.reference}") end}
                >
                  <:col :let={row} label="Reference">
                    <.kbd>{row.reference}</.kbd>
                  </:col>
                  <:col :let={row} label="Customer">{row.customer}</:col>
                  <:col :let={row} label="Total" align={:right}>
                    {format_money(@settings.currency, row.total)}
                  </:col>
                  <:empty>
                    <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                      No orders scheduled for today.
                    </div>
                  </:empty>
                </.table>
              </Page.surface>

              <Page.surface>
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Outstanding today</h3>
                    <p class="text-xs text-stone-500">
                      Quantities still to prep and those mid-production.
                    </p>
                  </div>
                </:header>
                <.table
                  id="outstanding-today"
                  rows={@overview_tables.outstanding_today}
                  variant={:compact}
                  zebra
                  no_margin
                >
                  <:col :let={row} label="Product">{row.product.name}</:col>
                  <:col :let={row} label="Todo Qty" align={:right}>{row.todo}</:col>
                  <:col :let={row} label="In Progress Qty" align={:right}>{row.in_progress}</:col>
                  <:empty>
                    <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                      All production tasks are caught up.
                    </div>
                  </:empty>
                </.table>
              </Page.surface>

              <Page.surface>
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Over-capacity details</h3>
                    <p class="text-xs text-stone-500">
                      Products that exceed their daily limit.
                    </p>
                  </div>
                </:header>
                <.table
                  id="over-capacity-details"
                  rows={@overview_tables.over_capacity}
                  variant={:compact}
                  zebra
                  no_margin
                >
                  <:col :let={row} label="Day">{Calendar.strftime(row.day, "%a %d")}</:col>
                  <:col :let={row} label="Product">{row.product.name}</:col>
                  <:col :let={row} label="Scheduled" align={:right}>{row.qty}</:col>
                  <:col :let={row} label="Max" align={:right}>{row.max}</:col>
                  <:empty>
                    <div class="w-full rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                      Capacity looks balanced.
                    </div>
                  </:empty>
                </.table>
              </Page.surface>

              <Page.surface>
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Days over order capacity</h3>
                    <p class="text-xs text-stone-500">
                      When confirmed orders exceed the overall daily cap.
                    </p>
                  </div>
                </:header>
                <.table
                  id="over-order-capacity"
                  rows={@overview_tables.over_order_capacity}
                  variant={:compact}
                  zebra
                  no_margin
                >
                  <:col :let={row} label="Day">{Calendar.strftime(row.day, "%a %d")}</:col>
                  <:col :let={row} label="Orders" align={:right}>{row.count}</:col>
                  <:col :let={row} label="Cap" align={:right}>{row.cap}</:col>
                  <:empty>
                    <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                      No upcoming days over your order capacity.
                    </div>
                  </:empty>
                </.table>
              </Page.surface>
            </Page.form_grid>
            <Page.form_grid columns={2}>
              <Page.surface class="mt-4 lg:col-span-2 xl:col-span-3">
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Material shortages</h3>
                    <p class="text-xs text-stone-500">
                      Where inventory falls short once production is applied.
                    </p>
                  </div>
                </:header>
                <.table
                  id="material-shortages"
                  rows={@overview_tables.shortage}
                  variant={:compact}
                  zebra
                  no_margin
                  row_click={fn row -> JS.navigate("/manage/inventory/#{row.material.sku}") end}
                >
                  <:col :let={row} label="Day">{Calendar.strftime(row.day, "%a %d")}</:col>
                  <:col :let={row} label="Material">{row.material.name}</:col>
                  <:col :let={row} label="Required" align={:right}>
                    {format_amount(row.material.unit, row.required)}
                  </:col>
                  <:col :let={row} label="Opening" align={:right}>
                    {format_amount(row.material.unit, row.opening)}
                  </:col>
                  <:col :let={row} label="End Balance" align={:right}>
                    {format_amount(row.material.unit, row.ending)}
                  </:col>
                  <:empty>
                    <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                      Stock levels look healthy for the selected range.
                    </div>
                  </:empty>
                </.table>
              </Page.surface>
            </Page.form_grid>
          </Page.section>
        </:left>
        <:right>
          <Page.surface padding="p-5">
            <:header>
              <div>
                <h3 class="text-sm font-semibold text-stone-900">Quick actions</h3>
                <p class="text-xs text-stone-500">
                  Stay aligned as production plans shift.
                </p>
              </div>
            </:header>
            <div class="space-y-3 text-sm text-stone-600">
              <p>
                Jump to the tools your team relies on most when orders change.
              </p>
              <div class="space-y-2">
                <.link
                  patch={~p"/manage/production/schedule?view=week"}
                  class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                >
                  <.icon name="hero-calendar-days" class="h-4 w-4" /> Review weekly schedule
                </.link>
                <.link
                  patch={~p"/manage/production/make_sheet"}
                  class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                >
                  <.icon name="hero-document-text" class="h-4 w-4" /> Print make sheet
                </.link>
                <.link
                  patch={~p"/manage/inventory/forecast"}
                  class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                >
                  <.icon name="hero-beaker" class="h-4 w-4" /> Check material forecast
                </.link>
              </div>
            </div>
          </Page.surface>
        </:right>
      </Page.two_column>

      <div :if={@live_action == :schedule} class="mt-4">
        <div class="mt-8">
          <div
            id="controls"
            class="border-gray-200/70 flex items-center justify-between border-b pb-4"
          >
            <div></div>
            <div class="flex items-center space-x-4">
              <!-- View toggle -->
              <div class="mr-2 hidden items-center sm:flex">
                <button
                  phx-click="set_schedule_view"
                  phx-value-view="week"
                  aria-pressed={@schedule_view == :week}
                  class={[
                    "rounded-l-md border border-stone-300 px-2 py-1 text-xs transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-400",
                    (@schedule_view == :week && "border-blue-300 bg-blue-100 text-blue-700") ||
                      "bg-white text-stone-700 hover:bg-blue-50"
                  ]}
                >
                  Week
                </button>
                <button
                  phx-click="set_schedule_view"
                  phx-value-view="day"
                  aria-pressed={@schedule_view == :day}
                  class={[
                    "rounded-r-md border border-l-0 border-stone-300 px-2 py-1 text-xs transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-400",
                    (@schedule_view == :day && "border-blue-300 bg-blue-100 text-blue-700") ||
                      "bg-white text-stone-700 hover:bg-blue-50"
                  ]}
                >
                  Day
                </button>
              </div>
              
    <!-- Prev / Today / Next segmented control -->
              <div class="flex items-center">
                <button
                  phx-click="previous_week"
                  size={:sm}
                  title="Previous"
                  class="px-[6px] cursor-pointer rounded-l-md border border-stone-300 bg-white py-1 transition-colors hover:bg-stone-50 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-400"
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
                  aria-pressed={@is_today}
                  title="Jump to today"
                  class={[
                    "flex cursor-pointer items-center border-y border-r border-l-0 border-stone-300 bg-white px-3 py-1 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-400 disabled:cursor-default disabled:bg-stone-100 disabled:text-stone-400",
                    (@is_today && "border-blue-300 bg-blue-100 text-blue-700") ||
                      "text-stone-700 hover:bg-blue-50"
                  ]}
                  disabled={@is_today}
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
                  title="Next"
                  class="px-[6px] cursor-pointer rounded-r-md border border-l-0 border-stone-300 bg-white py-1 transition-colors hover:bg-stone-50 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-400"
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
            <% day = List.first(@days_range) %>

            <div class="absolute left-1/2 -translate-x-1/2 transform">
              <span class="inline-flex items-center space-x-2 font-medium text-stone-700">
                <span>
                  {Calendar.strftime(List.first(@days_range), "%B %Y")}
                </span>
                <div :if={@schedule_view == :day} class="inline-flex items-center space-x-2">
                  <span>
                    //
                  </span>
                  <span>
                    {format_day_name(day)}
                  </span>
                  <span>
                    {format_short_date(day, @time_zone)}
                  </span>
                </div>
              </span>
            </div>
          </div>

          <%= if @schedule_view == :day do %>
            <%!-- Kanban View for Daily Schedule --%>
            <div class="mt-4" phx-hook="KanbanDragDrop" id="kanban-board">
              <% kanban = get_kanban_columns_for_day(day, @production_items) %>
              <div class="grid grid-cols-3 gap-4">
                <%!-- To Do Column --%>
                <div class="flex flex-col">
                  <div class="rounded-t-lg border border-slate-300 bg-slate-50 px-4 py-3">
                    <div class="flex items-center justify-between">
                      <h3 class="font-semibold text-slate-700">To Do</h3>
                      <span class="rounded-full bg-slate-200 px-2 py-0.5 text-xs font-medium text-slate-700">
                        {length(kanban.todo)}
                      </span>
                    </div>
                  </div>
                  <div
                    class="kanban-column min-h-[60vh] bg-slate-50/50 space-y-3 rounded-b-lg border border-t-0 border-slate-300 p-3"
                    data-status="todo"
                    phx-hook="KanbanColumn"
                    id="kanban-column-todo"
                  >
                    <div
                      :for={{product, items} <- kanban.todo}
                      phx-click="view_details"
                      phx-value-date={Date.to_iso8601(day)}
                      phx-value-product={product.id}
                      class="kanban-card group cursor-move rounded-lg border border-slate-300 bg-white p-3 transition-all hover:shadow-md"
                      draggable="true"
                      data-product-id={product.id}
                      data-date={Date.to_iso8601(day)}
                      data-status="todo"
                    >
                      <div class="mb-2 flex items-start justify-between gap-2">
                        <span class="font-medium text-stone-800" title={product.name}>
                          {product.name}
                        </span>
                        <.badge
                          :if={
                            capacity_status(
                              product,
                              get_product_items_for_day(day, product, @production_items)
                            ) == :over
                          }
                          text="Over cap"
                        />
                      </div>
                      <div class="flex items-center justify-between text-sm text-stone-600">
                        <span class="flex items-center">
                          <svg
                            class="mr-1 h-4 w-4"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                            />
                          </svg>
                          {format_amount(:piece, total_quantity(items))}
                        </span>
                      </div>
                    </div>
                    <div
                      :if={Enum.empty?(kanban.todo)}
                      class="flex items-center justify-center py-8 text-sm text-stone-400"
                    >
                      No items
                    </div>
                  </div>
                </div>

                <%!-- In Progress Column --%>
                <div class="flex flex-col">
                  <div class="rounded-t-lg border border-blue-300 bg-blue-50 px-4 py-3">
                    <div class="flex items-center justify-between">
                      <h3 class="font-semibold text-blue-700">In Progress</h3>
                      <span class="rounded-full bg-blue-200 px-2 py-0.5 text-xs font-medium text-blue-700">
                        {length(kanban.in_progress)}
                      </span>
                    </div>
                  </div>
                  <div
                    class="kanban-column min-h-[60vh] bg-blue-50/50 space-y-3 rounded-b-lg border border-t-0 border-blue-300 p-3"
                    data-status="in_progress"
                    phx-hook="KanbanColumn"
                    id="kanban-column-in-progress"
                  >
                    <div
                      :for={{product, items} <- kanban.in_progress}
                      phx-click="view_details"
                      phx-value-date={Date.to_iso8601(day)}
                      phx-value-product={product.id}
                      class="kanban-card group cursor-move rounded-lg border border-blue-300 bg-white p-3 transition-all hover:shadow-md"
                      draggable="true"
                      data-product-id={product.id}
                      data-date={Date.to_iso8601(day)}
                      data-status="in_progress"
                    >
                      <div class="mb-2 flex items-start justify-between gap-2">
                        <span class="font-medium text-stone-800" title={product.name}>
                          {product.name}
                        </span>
                        <.badge
                          :if={
                            capacity_status(
                              product,
                              get_product_items_for_day(day, product, @production_items)
                            ) == :over
                          }
                          text="Over cap"
                        />
                      </div>
                      <div class="flex items-center justify-between text-sm text-stone-600">
                        <span class="flex items-center">
                          <svg
                            class="mr-1 h-4 w-4"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          {format_amount(:piece, total_quantity(items))}
                        </span>
                      </div>
                    </div>
                    <div
                      :if={Enum.empty?(kanban.in_progress)}
                      class="flex items-center justify-center py-8 text-sm text-stone-400"
                    >
                      No items
                    </div>
                  </div>
                </div>

                <%!-- Done Column --%>
                <div class="flex flex-col">
                  <div class="rounded-t-lg border border-green-300 bg-green-50 px-4 py-3">
                    <div class="flex items-center justify-between">
                      <h3 class="font-semibold text-green-700">Done</h3>
                      <span class="rounded-full bg-green-200 px-2 py-0.5 text-xs font-medium text-green-700">
                        {length(kanban.done)}
                      </span>
                    </div>
                  </div>
                  <div
                    class="kanban-column min-h-[60vh] bg-green-50/50 space-y-3 rounded-b-lg border border-t-0 border-green-300 p-3"
                    data-status="done"
                    phx-hook="KanbanColumn"
                    id="kanban-column-done"
                  >
                    <div
                      :for={{product, items} <- kanban.done}
                      phx-click="view_details"
                      phx-value-date={Date.to_iso8601(day)}
                      phx-value-product={product.id}
                      class="kanban-card group cursor-move rounded-lg border border-green-300 bg-white p-3 transition-all hover:shadow-md"
                      draggable="true"
                      data-product-id={product.id}
                      data-date={Date.to_iso8601(day)}
                      data-status="done"
                    >
                      <div class="mb-2 flex items-start justify-between gap-2">
                        <span class="font-medium text-stone-800" title={product.name}>
                          {product.name}
                        </span>
                        <.badge
                          :if={
                            capacity_status(
                              product,
                              get_product_items_for_day(day, product, @production_items)
                            ) == :over
                          }
                          text="Over cap"
                        />
                      </div>
                      <div class="flex items-center justify-between text-sm text-stone-600">
                        <span class="flex items-center">
                          <svg
                            class="mr-1 h-4 w-4"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          {format_amount(:piece, total_quantity(items))}
                        </span>
                      </div>
                    </div>
                    <div
                      :if={Enum.empty?(kanban.done)}
                      class="flex items-center justify-center py-8 text-sm text-stone-400"
                    >
                      No items
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <%!-- Week View --%>
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
                          is_today?(day) && "bg-indigo-100/50 border border-indigo-300",
                          is_today?(Date.add(day, 1)) && "border-r border-r-indigo-300"
                        ]
                        |> Enum.filter(& &1)
                        |> Enum.join("  ")
                      }
                    >
                      <div class={["flex items-center justify-center"]}>
                        <div class={[
                          "inline-flex items-center justify-center space-x-1 rounded px-2",
                          is_today?(day) && "bg-indigo-500 text-white"
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
                          is_today?(day) && "bg-indigo-100/50 border border-indigo-300",
                          is_today?(Date.add(day, 1)) && "border-r border-r-indigo-300",
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
          <% end %>
        </div>
      </div>
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
              <.button variant={:primary} phx-click="consume_all_today">
                Consume All Completed
              </.button>
              <.button variant={:outline} onclick="window.print()">Print</.button>
            </div>
          </div>
          <div class="rounded border border-stone-300 bg-white p-4 print:border-black">
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
              <:col :let={row} label="Required">
                {format_amount(row.material.unit, row.required)}
              </:col>
              <:col :let={row} label="Current Stock">
                {format_amount(row.material.unit, row.current_stock || Decimal.new(0))}
              </:col>
            </.table>
            <div class="mt-3 flex space-x-2">
              <.button variant={:primary} phx-click="confirm_consume">Consume Now</.button>
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
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    days_range = generate_week_range(today)

    socket =
      socket
      |> assign(:today, today)
      # set before computing is_today
      |> assign(:schedule_view, :day)
      |> update_for_range(days_range)
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
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action
    current_view = socket.assigns[:schedule_view] || :day

    schedule_view =
      if live_action in [:schedule, :make_sheet] do
        case Map.get(params, "view") do
          "week" -> :week
          "day" -> :day
          _ -> current_view
        end
      else
        current_view
      end

    socket =
      socket
      |> maybe_assign_schedule_view(live_action, schedule_view)
      |> assign(:page_title, page_title(live_action))

    {:noreply, Navigation.assign(socket, :production, plan_trail(socket.assigns))}
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
    step = if socket.assigns.schedule_view == :day, do: 1, else: 7
    monday = List.first(socket.assigns.days_range)
    new_start = Date.add(monday, -step)
    days_range = generate_week_range(new_start)
    {:noreply, update_for_range(socket, days_range)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    step = if socket.assigns.schedule_view == :day, do: 1, else: 7
    monday = List.first(socket.assigns.days_range)
    new_start = Date.add(monday, step)
    days_range = generate_week_range(new_start)
    {:noreply, update_for_range(socket, days_range)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    today = Date.utc_today()

    days_range =
      case socket.assigns.schedule_view do
        :day -> generate_week_range(today, 1)
        _ -> generate_current_week_range()
      end

    {:noreply,
     socket
     |> assign(:today, today)
     |> update_for_range(days_range)}
  end

  @impl true
  def handle_event("set_schedule_view", %{"view" => view}, socket) do
    schedule_view = if view == "day", do: :day, else: :week

    anchor = List.first(socket.assigns.days_range)

    days_range =
      case schedule_view do
        :day ->
          generate_week_range(anchor, 1)

        :week ->
          monday = Date.add(anchor, -(Date.day_of_week(anchor) - 1))
          generate_week_range(monday, 7)
      end

    socket =
      socket
      |> assign(:schedule_view, schedule_view)
      |> update_for_range(days_range)

    {:noreply, Navigation.assign(socket, :production, plan_trail(socket.assigns))}
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
  def handle_event(
        "update_kanban_status",
        %{"product_id" => product_id, "date" => date_str, "status" => new_status},
        socket
      ) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        new_status_atom = String.to_atom(new_status)

        items =
          get_product_items_for_day(date, %{id: product_id}, socket.assigns.production_items)

        Enum.each(items, fn item ->
          Orders.update_item(item, %{status: new_status_atom}, actor: socket.assigns.current_user)
        end)

        days_range = socket.assigns.days_range
        socket = update_for_range(socket, days_range)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update status")}
    end
  end

  def handle_event("update_item_status", %{"item_id" => id, "status" => status}, socket) do
    order_item = Orders.get_order_item_by_id!(id, actor: socket.assigns.current_user)

    case Orders.update_item(order_item, %{status: String.to_atom(status)}, actor: socket.assigns.current_user) do
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
            socket,
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
        socket,
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
          socket,
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

    days_range = socket.assigns.days_range
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    overview_tables =
      compute_overview_tables_from(
        socket,
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
      Production.fetch_orders_in_range(socket.assigns.time_zone, days_range, actor: socket.assigns.current_user)

    Production.build_production_items(orders)
  end

  defp prepare_materials_requirements(socket, days_range) do
    InventoryForecasting.prepare_materials_requirements(days_range, socket.assigns.current_user)
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

  defp find_product(socket, product_id) do
    Catalog.get_product_by_id!(product_id, actor: socket.assigns.current_user)
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

  defp find_material(socket, material_id) do
    Inventory.get_material_by_id!(material_id, actor: socket.assigns.current_user)
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
        actor: socket.assigns.current_user,
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

  defp maybe_assign_schedule_view(socket, live_action, schedule_view) do
    if live_action in [:schedule, :make_sheet] do
      assign(socket, :schedule_view, schedule_view)
    else
      socket
    end
  end

  defp plan_trail(%{live_action: :schedule}), do: [Navigation.root(:production), Navigation.page(:production, :schedule)]

  defp plan_trail(%{live_action: :make_sheet}),
    do: [Navigation.root(:production), Navigation.page(:production, :make_sheet)]

  defp plan_trail(%{live_action: :materials}),
    do: [Navigation.root(:production), Navigation.page(:production, :materials)]

  defp plan_trail(_), do: [Navigation.root(:production)]

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

    tz = socket.assigns.time_zone
    start_dt = days_range |> List.first() |> DateTime.new!(~T[00:00:00], tz)
    end_dt = days_range |> List.last() |> DateTime.new!(~T[23:59:59], tz)

    orders =
      Orders.list_orders!(
        %{delivery_date_start: start_dt, delivery_date_end: end_dt},
        actor: socket.assigns.current_user
      )

    orders_by_day = Enum.group_by(orders, fn o -> DateTime.to_date(o.delivery_date) end)
    cap = socket.assigns.settings.daily_capacity || 0

    over_order_capacity_days =
      if cap > 0 do
        Enum.count(days_range, fn day -> length(Map.get(orders_by_day, day, [])) > cap end)
      else
        0
      end

    material_shortage_days =
      Enum.count(days_range, fn day ->
        Enum.any?(materials_requirements, fn {_material, data} ->
          case Enum.find_index(data.quantities, fn {_, d} -> Date.compare(d, day) == :eq end) do
            nil ->
              false

            idx ->
              {balance, _} =
                Enum.reduce(Enum.take(data.quantities, idx + 1), {Decimal.new(0), nil}, fn {q, _d}, {_bal, _} ->
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

  defp compute_overview_tables_from(socket, assigns) do
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

    tz = assigns.time_zone
    cap = assigns.settings.daily_capacity || 0

    over_order_capacity_rows =
      if cap > 0 do
        start_dt = assigns.days_range |> List.first() |> DateTime.new!(~T[00:00:00], tz)
        end_dt = assigns.days_range |> List.last() |> DateTime.new!(~T[23:59:59], tz)

        orders =
          Orders.list_orders!(
            %{
              delivery_date_start: start_dt,
              delivery_date_end: end_dt
            },
            actor: socket.assigns.current_user
          )

        orders_by_day = Enum.group_by(orders, fn o -> DateTime.to_date(o.delivery_date) end)

        Enum.flat_map(assigns.days_range, fn day ->
          cnt = length(Map.get(orders_by_day, day, []))
          if cnt > cap, do: [%{day: day, count: cnt, cap: cap}], else: []
        end)
      else
        []
      end

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

    today = Date.utc_today()
    start_dt = DateTime.new!(today, ~T[00:00:00], tz)
    end_dt = DateTime.new!(today, ~T[23:59:59], tz)

    orders_today_rows =
      %{delivery_date_start: start_dt, delivery_date_end: end_dt}
      |> Orders.list_orders!(
        load: [:total_cost, :reference, customer: [:full_name]],
        actor: socket.assigns.current_user
      )
      |> Enum.map(fn o ->
        %{reference: o.reference, customer: o.customer.full_name, total: o.total_cost}
      end)

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

  defp update_for_range(socket, days_range) do
    production_items = load_production_items(socket, days_range)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    week_metrics =
      compute_week_metrics(socket, days_range, production_items, materials_requirements)

    overview_tables =
      compute_overview_tables_from(
        socket,
        build_overview_assigns(socket, days_range, production_items, materials_requirements)
      )

    today = socket.assigns.today

    is_today =
      case socket.assigns.schedule_view do
        :day -> List.first(days_range) == today
        :week -> Enum.any?(days_range, &(&1 == today))
        _ -> false
      end

    socket
    |> assign(:days_range, days_range)
    |> assign(:production_items, production_items)
    |> assign(:materials_requirements, materials_requirements)
    |> assign(:week_metrics, week_metrics)
    |> assign(:overview_tables, overview_tables)
    |> assign(:is_today, is_today)
  end

  defp get_kanban_columns_for_day(day, production_items) do
    all_items = get_items_for_day(day, production_items)

    %{
      todo: group_items_by_status(all_items, :todo),
      in_progress: group_items_by_status(all_items, :in_progress),
      done: group_items_by_status(all_items, :done)
    }
  end

  defp group_items_by_status(product_items, status) do
    product_items
    |> Enum.map(fn {product, items} ->
      filtered_items = Enum.filter(items, fn item -> item.status == status end)
      if Enum.empty?(filtered_items), do: nil, else: {product, filtered_items}
    end)
    |> Enum.reject(&is_nil/1)
  end
end
