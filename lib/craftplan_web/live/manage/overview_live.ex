defmodule CraftplanWeb.OverviewLive do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders
  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  require Ash.Query

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
                  <:col :let={row} label="Day">{format_date(row.day, format: "%a %d")}</:col>
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
                  <:col :let={row} label="Day">{format_date(row.day, format: "%a %d")}</:col>
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
                    <h3 class="text-sm font-semibold text-stone-900">Upcoming material shortages</h3>
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
                  <:col :let={row} label="Day">{format_date(row.day, format: "%a %d")}</:col>
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
      </Page.two_column>

      <div :if={@live_action == :schedule} class="mt-4">
        <div class="mt-8">
          <div
            id="controls"
            class="border-gray-200/70 flex items-center justify-between border-b pb-4"
          >
            <% day = List.first(@days_range) %>
            <div>
              <span class="inline-flex items-center space-x-2 font-medium text-stone-700">
                <span>
                  {format_date(List.first(@days_range), format: "%B %Y")}
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
          </div>

          <%= if @schedule_view == :day do %>
            <% {unbatched, batched} = split_day_items(day, @production_items, @allocation_map) %>
            <div
              :if={Enum.empty?(unbatched) && Enum.empty?(batched)}
              class="mt-4 rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500"
            >
              No production scheduled for this day.
            </div>
            <div
              :if={!Enum.empty?(unbatched) || !Enum.empty?(batched)}
              id="kanban-batches"
              phx-hook="KanbanDragDrop"
              class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4"
            >
              <%!-- Unbatched column --%>
              <div class="kanban-column rounded-lg bg-stone-50 p-3" data-status="unbatched">
                <h4 class="mb-2 text-xs font-semibold uppercase text-stone-400">Unbatched</h4>
                <div class="space-y-2">
                  <.unbatched_kanban_card
                    :for={{product, items} <- unbatched}
                    product={product}
                    items={items}
                    day={day}
                  />
                </div>
              </div>
              <%!-- Open column --%>
              <div class="kanban-column bg-blue-50/50 rounded-lg p-3" data-status="open">
                <h4 class="mb-2 text-xs font-semibold uppercase text-blue-600">Open</h4>
                <div class="space-y-2">
                  <.batch_kanban_card
                    :for={bg <- Enum.filter(batched, &(&1.status == :open))}
                    batch_group={bg}
                  />
                </div>
              </div>
              <%!-- In Progress column --%>
              <div class="kanban-column bg-amber-50/50 rounded-lg p-3" data-status="in_progress">
                <h4 class="mb-2 text-xs font-semibold uppercase text-amber-600">In Progress</h4>
                <div class="space-y-2">
                  <.batch_kanban_card
                    :for={bg <- Enum.filter(batched, &(&1.status == :in_progress))}
                    batch_group={bg}
                  />
                </div>
              </div>
              <%!-- Completed column --%>
              <div class="kanban-column bg-green-50/50 rounded-lg p-3" data-status="completed">
                <h4 class="mb-2 text-xs font-semibold uppercase text-green-600">Done</h4>
                <div class="space-y-2">
                  <.batch_kanban_card
                    :for={bg <- Enum.filter(batched, &(&1.status == :completed))}
                    batch_group={bg}
                  />
                </div>
              </div>
            </div>

            <%!-- Batch detail modal --%>
            <.modal
              :if={@selected_batch}
              id="batch-detail-modal"
              show
              title={@selected_batch.batch_code}
              on_cancel={JS.push("close_batch_modal")}
            >
              <div class="space-y-4 px-4 py-3">
                <div class="flex items-center justify-between">
                  <div>
                    <span class="text-lg font-medium text-stone-900">
                      {@selected_batch.product.name}
                    </span>
                    <span class={[
                      "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                      batch_status_class(@selected_batch.status)
                    ]}>
                      {batch_status_label(@selected_batch.status)}
                    </span>
                  </div>
                  <span class="text-sm text-stone-500">
                    {format_amount(:piece, total_quantity(@selected_batch.items))} &middot; {length(
                      Enum.uniq_by(@selected_batch.items, & &1.order.id)
                    )} orders
                  </span>
                </div>

                <%!-- Order details --%>
                <div class="space-y-2">
                  <h4 class="text-xs font-semibold uppercase text-stone-400">Orders</h4>
                  <div
                    :for={item <- @selected_batch.items}
                    class="flex items-center justify-between rounded border border-stone-100 bg-stone-50 px-3 py-2 text-sm"
                  >
                    <div class="flex items-center gap-2">
                      <.link
                        navigate={~p"/manage/orders/#{item.order.reference}/items"}
                        class="font-medium text-blue-700 hover:underline"
                      >
                        <.kbd>{format_reference(item.order.reference)}</.kbd>
                      </.link>
                      <span class="text-stone-500">{item.order.customer.full_name}</span>
                    </div>
                    <span class="text-stone-700">{item.quantity} pcs</span>
                  </div>
                </div>

                <%!-- Action buttons --%>
                <div class="flex items-center justify-between border-t border-stone-200 pt-3">
                  <.link
                    navigate={~p"/manage/production/batches/#{@selected_batch.batch_code}"}
                    class="text-sm font-medium text-blue-700 hover:underline"
                  >
                    View full batch &rarr;
                  </.link>
                  <div class="flex items-center gap-2">
                    <%= case @selected_batch.status do %>
                      <% :open -> %>
                        <.button
                          size={:sm}
                          variant={:outline}
                          phx-click={
                            JS.push("start_batch",
                              value: %{"batch-code" => @selected_batch.batch_code}
                            )
                          }
                        >
                          Start
                        </.button>
                      <% :in_progress -> %>
                        <.button
                          :if={!@completing_batch_code}
                          size={:sm}
                          variant={:outline}
                          phx-click={
                            JS.push("toggle_complete_form",
                              value: %{"batch-code" => @selected_batch.batch_code}
                            )
                          }
                        >
                          Mark Done
                        </.button>
                      <% _ -> %>
                    <% end %>
                  </div>
                </div>

                <%!-- Inline completion form --%>
                <div
                  :if={@completing_batch_code == @selected_batch.batch_code}
                  class="rounded-lg border border-stone-200 bg-stone-50 p-4"
                >
                  <.form
                    id={"complete-form-#{@selected_batch.batch_code}"}
                    for={%{}}
                    phx-submit="complete_batch"
                  >
                    <input type="hidden" name="batch-code" value={@selected_batch.batch_code} />
                    <div class="flex items-end gap-4">
                      <div class="flex-1">
                        <.input
                          type="number"
                          name="produced_qty"
                          label="Produced qty"
                          value={total_quantity(@selected_batch.items) |> Decimal.to_string()}
                          min="0"
                          step="any"
                          required
                        />
                      </div>
                      <div class="flex-1">
                        <.input
                          type="number"
                          name="duration_minutes"
                          label="Duration (min)"
                          value=""
                          placeholder="optional"
                          min="0"
                          step="any"
                        />
                      </div>
                      <div class="flex items-center gap-2 pb-1">
                        <.button
                          size={:sm}
                          variant={:outline}
                          type="button"
                          phx-click={
                            JS.push("toggle_complete_form",
                              value: %{"batch-code" => @selected_batch.batch_code}
                            )
                          }
                        >
                          Cancel
                        </.button>
                        <.button size={:sm} variant={:primary} type="submit">
                          Complete
                        </.button>
                      </div>
                    </div>
                  </.form>
                </div>
              </div>
            </.modal>

            <%!-- Unbatched detail modal --%>
            <.modal
              :if={@selected_unbatched}
              id="unbatched-detail-modal"
              show
              title={@selected_unbatched.product.name}
              on_cancel={JS.push("close_batch_modal")}
            >
              <div class="space-y-4 px-4 py-3">
                <div class="flex items-center justify-between">
                  <span class="inline-flex items-center rounded-full bg-stone-100 px-2.5 py-0.5 text-xs font-medium text-stone-600">
                    Not Batched
                  </span>
                  <span class="text-sm text-stone-500">
                    {format_amount(:piece, total_quantity(@selected_unbatched.items))} &middot; {length(
                      Enum.uniq_by(@selected_unbatched.items, & &1.order.id)
                    )} orders
                  </span>
                </div>

                <div class="space-y-2">
                  <h4 class="text-xs font-semibold uppercase text-stone-400">Orders</h4>
                  <div
                    :for={item <- @selected_unbatched.items}
                    class="flex items-center justify-between rounded border border-stone-100 bg-stone-50 px-3 py-2 text-sm"
                  >
                    <div class="flex items-center gap-2">
                      <.link
                        navigate={~p"/manage/orders/#{item.order.reference}/items"}
                        class="font-medium text-blue-700 hover:underline"
                      >
                        <.kbd>{format_reference(item.order.reference)}</.kbd>
                      </.link>
                      <span class="text-stone-500">{item.order.customer.full_name}</span>
                    </div>
                    <span class="text-stone-700">{item.quantity} pcs</span>
                  </div>
                </div>

                <div class="border-t border-stone-200 pt-3">
                  <.button
                    size={:sm}
                    variant={:outline}
                    phx-click={
                      JS.push("create_batch",
                        value: %{
                          date: Date.to_iso8601(@selected_unbatched.day),
                          product_id: @selected_unbatched.product.id
                        }
                      )
                    }
                  >
                    Batch All
                  </.button>
                </div>
              </div>
            </.modal>
          <% else %>
            <%!-- Week View --%>
            <div class="w-full overflow-x-auto">
              <table class="min-w-[1000px] w-full table-fixed border-collapse">
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
                          index > 0 && "border-l",
                          index < 6 && "border-r",
                          is_today?(day) && "bg-indigo-100/50 border-r-indigo-300",
                          is_today?(Date.add(day, 1)) && "border-r-indigo-300"
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
                          "min-h-[200px] w-1/7 overflow-hidden border-stone-200 p-2 align-top",
                          "border-t border-t-stone-200",
                          index > 0 && "border-l",
                          index < 6 && "border-r",
                          is_today?(day) && "bg-indigo-100/50 border-r-indigo-300",
                          is_today?(Date.add(day, 1)) && "border-r-indigo-300"
                        ]
                        |> Enum.filter(& &1)
                        |> Enum.join("  ")
                      }
                    >
                      <div class="h-full overflow-y-auto">
                        <% {wk_unbatched, wk_batched} =
                          split_day_items(day, @production_items, @allocation_map) %>
                        <%!-- Unbatched items in week view --%>
                        <div
                          :for={{product, items} <- wk_unbatched}
                          phx-click={
                            JS.patch(
                              ~p"/manage/production/schedule?view=day&date=#{Date.to_iso8601(day)}"
                            )
                          }
                          class={[
                            "group mb-2 cursor-pointer border p-2",
                            capacity_cell_class(product, items),
                            "hover:bg-stone-100"
                          ]}
                        >
                          <div class="mb-1.5 flex items-center justify-between gap-2 overflow-hidden">
                            <span class="min-w-0 truncate text-sm font-medium" title={product.name}>
                              {product.name}
                            </span>
                            <.badge
                              :if={capacity_status(product, items) == :over}
                              text="Over capacity"
                              class="flex-shrink-0"
                            />
                          </div>
                          <div class="mt-1.5 flex items-center justify-between text-xs text-stone-500">
                            <span>
                              {format_amount(:piece, total_quantity(items))}
                            </span>
                            <span class="text-[10px] inline-flex flex-shrink-0 items-center rounded-full bg-stone-100 px-1.5 py-0.5 font-medium text-stone-600">
                              Unbatched
                            </span>
                          </div>
                        </div>
                        <%!-- Batched items in week view --%>
                        <div
                          :for={batch_group <- wk_batched}
                          phx-click={
                            JS.patch(
                              ~p"/manage/production/schedule?view=day&date=#{Date.to_iso8601(day)}"
                            )
                          }
                          class={[
                            "group mb-2 cursor-pointer border p-2",
                            capacity_cell_class(batch_group.product, batch_group.items),
                            "hover:bg-stone-100"
                          ]}
                        >
                          <div class="mb-1.5 flex items-center justify-between gap-2 overflow-hidden">
                            <span
                              class="min-w-0 truncate text-sm font-medium"
                              title={batch_group.product.name}
                            >
                              {batch_group.product.name}
                            </span>
                            <.badge
                              :if={capacity_status(batch_group.product, batch_group.items) == :over}
                              text="Over capacity"
                              class="flex-shrink-0"
                            />
                          </div>
                          <div class="mt-1.5 flex items-center justify-between text-xs text-stone-500">
                            <span>
                              {format_amount(:piece, total_quantity(batch_group.items))}
                            </span>
                            <span class={[
                              "text-[10px] inline-flex flex-shrink-0 items-center rounded-full px-1.5 py-0.5 font-medium",
                              batch_status_class(batch_group.status)
                            ]}>
                              {batch_status_label(batch_group.status)}
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
    </Page.page>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    days_range = date_range(today, days: 1)

    socket =
      socket
      |> assign(:today, today)
      # set before computing is_today
      |> assign(:schedule_view, :day)
      |> update_for_range(days_range)
      |> assign(:selected_material_date, nil)
      |> assign(:selected_material, nil)
      |> assign(:material_details, nil)
      |> assign(:material_day_quantity, nil)
      |> assign(:material_day_balance, nil)
      |> assign(:expanded_card, nil)
      |> assign(:completing_batch_code, nil)
      |> assign(:selected_batch, nil)
      |> assign(:selected_unbatched, nil)

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

    section =
      if live_action in [:schedule, :make_sheet, :materials], do: :production, else: :overview

    # Determine anchor date from URL param or current range
    url_date =
      case Map.get(params, "date") do
        nil -> nil
        date_str -> Date.from_iso8601!(date_str)
      end

    # Re-compute days_range when view or date changes via URL param
    socket =
      cond do
        live_action in [:schedule, :make_sheet] and not is_nil(url_date) ->
          days_range =
            case schedule_view do
              :day -> date_range(url_date, days: 1)
              :week -> url_date |> beginning_of_week() |> date_range()
            end

          socket
          |> assign(:schedule_view, schedule_view)
          |> assign(:expanded_card, nil)
          |> assign(:completing_batch_code, nil)
          |> update_for_range(days_range)

        live_action in [:schedule, :make_sheet] and schedule_view != current_view ->
          anchor = List.first(socket.assigns.days_range)

          days_range =
            case schedule_view do
              :day -> date_range(anchor, days: 1)
              :week -> anchor |> beginning_of_week() |> date_range()
            end

          socket
          |> assign(:schedule_view, schedule_view)
          |> assign(:expanded_card, nil)
          |> assign(:completing_batch_code, nil)
          |> update_for_range(days_range)

        true ->
          maybe_assign_schedule_view(socket, live_action, schedule_view)
      end

    socket = assign(socket, :page_title, page_title(live_action))

    {:noreply, Navigation.assign(socket, section, plan_trail(socket.assigns))}
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
    days_range = date_range(new_start, days: length(socket.assigns.days_range))
    {:noreply, update_for_range(socket, days_range)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    step = if socket.assigns.schedule_view == :day, do: 1, else: 7
    monday = List.first(socket.assigns.days_range)
    new_start = Date.add(monday, step)
    days_range = date_range(new_start, days: length(socket.assigns.days_range))
    {:noreply, update_for_range(socket, days_range)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    today = Date.utc_today()

    days_range =
      case socket.assigns.schedule_view do
        :day -> date_range(today, days: 1)
        _ -> today |> beginning_of_week() |> date_range()
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
          date_range(anchor, days: 1)

        :week ->
          anchor
          |> beginning_of_week()
          |> date_range()
      end

    socket =
      socket
      |> assign(:schedule_view, schedule_view)
      |> update_for_range(days_range)

    {:noreply, Navigation.assign(socket, :production, plan_trail(socket.assigns))}
  end

  @impl true
  def handle_event("toggle_card", %{"type" => type, "id" => id}, socket) do
    card_key =
      case type do
        "unbatched" -> {:unbatched, id}
        "batch" -> {:batch, id}
      end

    expanded =
      if socket.assigns.expanded_card == card_key, do: nil, else: card_key

    {:noreply,
     socket
     |> assign(:expanded_card, expanded)
     |> assign(:completing_batch_code, nil)}
  end

  @impl true
  def handle_event("open_batch_modal", %{"batch-code" => batch_code}, socket) do
    day = List.first(socket.assigns.days_range)

    {_unbatched, batched} =
      split_day_items(day, socket.assigns.production_items, socket.assigns.allocation_map)

    case Enum.find(batched, &(&1.batch_code == batch_code)) do
      nil ->
        {:noreply, socket}

      batch_group ->
        {:noreply, assign(socket, selected_batch: batch_group, selected_unbatched: nil)}
    end
  end

  @impl true
  def handle_event("open_unbatched_modal", %{"product-id" => product_id}, socket) do
    day = List.first(socket.assigns.days_range)

    {unbatched, _batched} =
      split_day_items(day, socket.assigns.production_items, socket.assigns.allocation_map)

    case Enum.find(unbatched, fn {product, _items} -> product.id == product_id end) do
      nil ->
        {:noreply, socket}

      {product, items} ->
        {:noreply,
         assign(socket,
           selected_unbatched: %{product: product, items: items, day: day},
           selected_batch: nil
         )}
    end
  end

  @impl true
  def handle_event("close_batch_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_batch, nil)
     |> assign(:selected_unbatched, nil)
     |> assign(:completing_batch_code, nil)}
  end

  @impl true
  def handle_event("create_batch", %{"date" => date_iso, "product_id" => product_id}, socket) do
    actor = socket.assigns.current_user
    {:ok, day} = Date.from_iso8601(date_iso)
    product = find_product(socket, product_id)

    items_for_product = get_product_items_for_day(day, product, socket.assigns.production_items)

    items_with_remaining =
      items_for_product
      |> Enum.map(fn item ->
        full =
          Orders.get_order_item_by_id!(item.id,
            load: [:quantity, :planned_qty_sum],
            actor: actor
          )

        planned = full.planned_qty_sum || Decimal.new(0)
        remaining = Decimal.sub(full.quantity, planned)
        %{id: full.id, remaining: remaining}
      end)
      |> Enum.filter(fn %{remaining: r} -> Decimal.compare(r, Decimal.new(0)) == :gt end)

    if Enum.empty?(items_with_remaining) do
      {:noreply, put_flash(socket, :info, "Nothing remaining to allocate for this product/day")}
    else
      planned_qty =
        Enum.reduce(items_with_remaining, Decimal.new(0), fn %{remaining: r}, acc ->
          Decimal.add(acc, r)
        end)

      case Orders.open_batch_with_allocations(
             %{
               product_id: product.id,
               planned_qty: planned_qty,
               allocations:
                 Enum.map(items_with_remaining, fn %{id: id, remaining: r} ->
                   %{order_item_id: id, planned_qty: r}
                 end)
             },
             actor: actor
           ) do
        {:ok, batch} ->
          {:noreply,
           socket
           |> put_flash(:info, "Batch #{batch.batch_code} created")
           |> assign(:selected_unbatched, nil)
           |> update_for_range(socket.assigns.days_range)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to create batch: #{inspect(error)}")}
      end
    end
  end

  @impl true
  def handle_event("start_batch", %{"batch-code" => batch_code}, socket) do
    actor = socket.assigns.current_user

    case Orders.get_production_batch_by_code(%{batch_code: batch_code}, actor: actor) do
      {:ok, batch} ->
        case Orders.start_batch(batch, %{}, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Batch #{batch_code} started")
             |> assign(:selected_batch, nil)
             |> update_for_range(socket.assigns.days_range)}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, "Failed to start batch: #{inspect(error)}")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Batch not found")}
    end
  end

  @impl true
  def handle_event("drop_batch", %{"batch_code" => code, "from" => from, "to" => to}, socket) do
    cond do
      from == to ->
        {:noreply, socket}

      # Backward drags
      to == "open" && from in ["in_progress", "completed"] ->
        {:noreply, put_flash(socket, :error, "Cannot move a batch backward")}

      from == "completed" ->
        {:noreply, put_flash(socket, :error, "Cannot move a completed batch")}

      # Skip open → completed
      from == "open" && to == "completed" ->
        {:noreply, put_flash(socket, :error, "Batch must be started before completing")}

      # Open → In Progress
      from == "open" && to == "in_progress" ->
        handle_event("start_batch", %{"batch-code" => code}, socket)

      # In Progress → Completed (open modal with completion form)
      from == "in_progress" && to == "completed" ->
        day = List.first(socket.assigns.days_range)

        {_unbatched, batched} =
          split_day_items(day, socket.assigns.production_items, socket.assigns.allocation_map)

        case Enum.find(batched, &(&1.batch_code == code)) do
          nil ->
            {:noreply, put_flash(socket, :error, "Batch not found")}

          batch_group ->
            {:noreply,
             socket
             |> assign(:completing_batch_code, code)
             |> assign(:selected_batch, batch_group)}
        end

      true ->
        {:noreply, put_flash(socket, :error, "Invalid transition")}
    end
  end

  @impl true
  def handle_event("drop_unbatched", %{"product_id" => product_id, "to" => to}, socket) do
    case to do
      "open" ->
        day = List.first(socket.assigns.days_range)

        handle_event(
          "create_batch",
          %{"date" => Date.to_iso8601(day), "product_id" => product_id},
          socket
        )

      "unbatched" ->
        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Unbatched items can only be moved to Open")}
    end
  end

  @impl true
  def handle_event("toggle_complete_form", %{"batch-code" => batch_code}, socket) do
    completing =
      if socket.assigns.completing_batch_code == batch_code, do: nil, else: batch_code

    {:noreply, assign(socket, :completing_batch_code, completing)}
  end

  @impl true
  def handle_event("complete_batch", params, socket) do
    batch_code = params["batch-code"] || params["batch_code"]
    produced_qty = params["produced_qty"]
    duration_minutes = params["duration_minutes"]
    actor = socket.assigns.current_user

    case Orders.get_production_batch_by_code(%{batch_code: batch_code}, actor: actor) do
      {:ok, batch} ->
        update_params =
          then(%{produced_qty: produced_qty}, fn p ->
            if duration_minutes && duration_minutes != "",
              do: Map.put(p, :duration_minutes, duration_minutes),
              else: p
          end)

        case Orders.complete_batch(batch, update_params, actor: actor) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Batch #{batch_code} completed — #{produced_qty} pcs produced")
             |> assign(:completing_batch_code, nil)
             |> assign(:selected_batch, nil)
             |> update_for_range(socket.assigns.days_range)}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, "Failed to complete batch: #{inspect(error)}")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Batch not found")}
    end
  end

  defp unbatched_kanban_card(assigns) do
    ~H"""
    <div
      class="kanban-card cursor-pointer rounded-lg border border-stone-200 bg-white p-3"
      phx-click="open_unbatched_modal"
      phx-value-product-id={@product.id}
      data-product-id={@product.id}
    >
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium text-stone-900">{@product.name}</span>
        <.badge :if={capacity_status(@product, @items) == :over} text="Over cap" />
      </div>
      <div class="mt-1.5 text-xs text-stone-500">
        {format_amount(:piece, total_quantity(@items))} &middot; {length(
          Enum.uniq_by(@items, & &1.order.id)
        )} orders
      </div>
    </div>
    """
  end

  defp batch_kanban_card(assigns) do
    ~H"""
    <div
      class="kanban-card cursor-pointer rounded-lg border border-stone-200 bg-white p-3"
      draggable="true"
      data-batch-code={@batch_group.batch_code}
      data-status={@batch_group.status}
      phx-click="open_batch_modal"
      phx-value-batch-code={@batch_group.batch_code}
    >
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-stone-900">{@batch_group.product.name}</span>
        <span class="font-mono text-xs text-stone-400">{@batch_group.batch_code}</span>
      </div>
      <div class="mt-1.5 text-xs text-stone-500">
        {format_amount(:piece, total_quantity(@batch_group.items))} &middot; {length(
          Enum.uniq_by(@batch_group.items, & &1.order.id)
        )} orders
      </div>
    </div>
    """
  end

  defp beginning_of_week(date) do
    Date.add(date, -(Date.day_of_week(date) - 1))
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
          items: [
            :quantity,
            product: [
              :name,
              active_bom: [:rollup]
            ]
          ]
        ]
      )

    InventoryForecasting.get_material_usage_details(
      material,
      orders,
      socket.assigns.current_user
    )
  end

  defp page_title(:schedule), do: "Plan: Schedule"
  defp page_title(:materials), do: "Plan: Inventory Forecast"
  defp page_title(:make_sheet), do: "Plan: Make Sheet"
  defp page_title(_), do: "Overview"

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

  defp plan_trail(_), do: [Navigation.root(:overview)]

  defp batch_status_label(:not_batched), do: "Not Batched"
  defp batch_status_label(:open), do: "Open"
  defp batch_status_label(:in_progress), do: "In Progress"
  defp batch_status_label(:completed), do: "Completed"

  defp batch_status_class(:not_batched), do: "bg-stone-100 text-stone-600"
  defp batch_status_class(:open), do: "bg-blue-100 text-blue-700"
  defp batch_status_class(:in_progress), do: "bg-amber-100 text-amber-700"
  defp batch_status_class(:completed), do: "bg-green-100 text-green-700"

  defp split_day_items(day, production_items, allocation_map) do
    all = get_items_for_day(day, production_items)

    unbatched =
      all
      |> Enum.map(fn {product, items} ->
        unb = Enum.filter(items, fn item -> not Map.has_key?(allocation_map, item.id) end)
        {product, unb}
      end)
      |> Enum.reject(fn {_, items} -> Enum.empty?(items) end)

    batched =
      all
      |> Enum.flat_map(fn {_product, items} -> items end)
      |> Enum.filter(fn item -> Map.has_key?(allocation_map, item.id) end)
      |> Enum.group_by(fn item -> allocation_map[item.id].batch_code end)
      |> Enum.map(fn {code, items} ->
        product = hd(items).product
        alloc_info = allocation_map[hd(items).id]

        %{
          batch_code: code,
          product: product,
          items: items,
          production_batch_id: alloc_info.batch_id,
          status: alloc_info.batch_status
        }
      end)
      |> Enum.sort_by(fn b ->
        case b.status do
          :completed -> 2
          :in_progress -> 0
          _ -> 1
        end
      end)

    {unbatched, batched}
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

    orders_by_day_counts = Map.get(socket.assigns, :orders_by_day_counts, %{})
    cap = socket.assigns.settings.daily_capacity || 0

    over_order_capacity_days =
      if cap > 0 do
        Enum.count(days_range, fn day -> Map.get(orders_by_day_counts, day, 0) > cap end)
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
    orders_by_day_counts = Map.get(socket.assigns, :orders_by_day_counts, %{})
    orders_today = Map.get(orders_by_day_counts, today, 0)

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

    cap = assigns.settings.daily_capacity || 0
    orders_by_day_counts = Map.get(socket.assigns, :orders_by_day_counts, %{})

    over_order_capacity_rows =
      if cap > 0 do
        Enum.flat_map(assigns.days_range, fn day ->
          cnt = Map.get(orders_by_day_counts, day, 0)
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

    orders_today_rows = Map.get(socket.assigns, :orders_today_rows, [])

    today = Date.utc_today()

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

    # Precompute orders by day (counts) and today's orders rows once per range
    {orders_by_day_counts, orders_today_rows} = fetch_orders_data(socket, days_range)

    socket =
      socket
      |> assign(:orders_by_day_counts, orders_by_day_counts)
      |> assign(:orders_today_rows, orders_today_rows)

    # Load allocation map: order_item_id -> {batch_code, batch_id, batch_status}
    item_ids =
      production_items
      |> Enum.flat_map(fn {_, _, items} -> items end)
      |> Enum.map(& &1.id)

    allocation_map = Production.allocation_map_for_items(item_ids, socket.assigns.current_user)

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
    |> assign(:allocation_map, allocation_map)
    |> assign(:week_metrics, week_metrics)
    |> assign(:overview_tables, overview_tables)
    |> assign(:is_today, is_today)
  end

  defp fetch_orders_data(socket, days_range) do
    tz = socket.assigns.time_zone
    start_dt = days_range |> List.first() |> DateTime.new!(~T[00:00:00], tz)
    end_dt = days_range |> List.last() |> DateTime.new!(~T[23:59:59], tz)

    orders =
      Orders.list_orders!(
        %{delivery_date_start: start_dt, delivery_date_end: end_dt},
        actor: socket.assigns.current_user
      )

    orders_by_day_counts =
      orders
      |> Enum.group_by(fn o -> DateTime.to_date(o.delivery_date) end)
      |> Map.new(fn {day, os} -> {day, length(os)} end)

    today = Date.utc_today()
    today_start = DateTime.new!(today, ~T[00:00:00], tz)
    today_end = DateTime.new!(today, ~T[23:59:59], tz)

    orders_today_rows =
      %{delivery_date_start: today_start, delivery_date_end: today_end}
      |> Orders.list_orders!(
        load: [:total_cost, :reference, customer: [:full_name]],
        actor: socket.assigns.current_user
      )
      |> Enum.map(fn o ->
        %{reference: o.reference, customer: o.customer.full_name, total: o.total_cost}
      end)

    {orders_by_day_counts, orders_today_rows}
  end
end
