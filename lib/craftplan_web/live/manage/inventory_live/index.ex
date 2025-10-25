defmodule CraftplanWeb.InventoryLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders
  alias CraftplanWeb.Components.Inventory, as: InventoryComponents
  alias CraftplanWeb.Components.Page

  require Logger

  @default_service_level 0.95
  @default_horizon_days 7
  @default_risk_filters [:shortage, :watch, :balanced]

  @impl true
  def render(assigns) do
    first_forecast_day =
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
      |> assign(:first_forecast_day, first_forecast_day)

    ~H"""
    <Page.page>
      <.header>
        Materials
        <:subtitle>
          Keep production ready by managing raw stock and forecasting demand.
        </:subtitle>
        <:actions :if={@live_action in [:index, :forecast]}>
          <.link patch={~p"/manage/inventory/new"}>
            <.button variant={:primary}>New Material</.button>
          </.link>
        </:actions>
      </.header>

      <Page.section>
        <Page.two_column :if={@live_action == :index}>
          <:left>
            <Page.surface>
              <:header>
                <div>
                  <h3 class="text-sm font-semibold text-stone-900">Material catalog</h3>
                  <p class="text-xs text-stone-500">
                    Browse SKUs, stock on hand, and pricing.
                  </p>
                </div>
              </:header>
              <.table
                id="materials"
                rows={@streams.materials}
                row_id={fn {dom_id, _} -> dom_id end}
                row_click={fn {_, material} -> JS.navigate(~p"/manage/inventory/#{material.sku}") end}
              >
                <:empty>
                  <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500">
                    No materials found. Add your first ingredient to start tracking stock.
                  </div>
                </:empty>
                <:col :let={{_, material}} label="Material">{material.name}</:col>
                <:col :let={{_, material}} label="SKU">
                  <.kbd>
                    {material.sku}
                  </.kbd>
                </:col>
                <:col :let={{_, material}} label="Current stock">
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
                    phx-click={
                      JS.push("delete", value: %{id: material.id}) |> hide("##{material.sku}")
                    }
                    data-confirm="Are you sure?"
                  >
                    <.button size={:sm} variant={:danger}>
                      Delete
                    </.button>
                  </.link>
                </:action>
              </.table>
            </Page.surface>
          </:left>
          <:right>
            <Page.surface padding="p-5">
              <:header>
                <div>
                  <h3 class="text-sm font-semibold text-stone-900">Quick actions</h3>
                  <p class="text-xs text-stone-500">
                    Keep inventory current as production shifts.
                  </p>
                </div>
              </:header>
              <div class="space-y-3 text-sm text-stone-600">
                <p>
                  Use these shortcuts to stay aligned with demand.
                </p>
                <div class="space-y-2">
                  <.link
                    patch={~p"/manage/inventory/forecast"}
                    class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                  >
                    <.icon name="hero-chart-bar-square" class="h-4 w-4" /> Review material forecast
                  </.link>
                  <.link
                    patch={~p"/manage/production"}
                    class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                  >
                    <.icon name="hero-arrow-path" class="h-4 w-4" /> Check production commitments
                  </.link>
                  <.link
                    patch={~p"/manage/settings/csv"}
                    class="text-primary-600 inline-flex items-center gap-2 transition hover:text-primary-700 hover:underline"
                  >
                    <.icon name="hero-arrow-down-tray" class="h-4 w-4" /> Import materials via CSV
                  </.link>
                </div>
              </div>
            </Page.surface>
          </:right>
        </Page.two_column>

        <Page.two_column
          :if={@live_action == :forecast}
          class="gap-6"
          right_class="space-y-4 lg:w-80 xl:w-96"
        >
          <:left>
            <div class="space-y-4">
              <div id="controls">
                <Page.surface padding="p-4">
                  <:header>
                    <div>
                      <h3 class="text-sm font-semibold text-stone-900">
                        {if @first_forecast_day,
                          do: Calendar.strftime(@first_forecast_day, "%B %Y"),
                          else: "Material forecast"}
                      </h3>
                      <p class="text-xs text-stone-500">
                        Track material requirements versus stock for the coming week.
                      </p>
                    </div>
                  </:header>
                  <:actions>
                    <div class="flex items-center overflow-hidden rounded-md border border-stone-300">
                      <button
                        type="button"
                        phx-click="today"
                        class="flex items-center gap-2 border-r border-stone-300 bg-white px-3 py-1 text-xs font-medium uppercase tracking-wide text-stone-600 transition hover:bg-stone-50"
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
                            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                          />
                        </svg>
                        Today
                      </button>
                      <button
                        type="button"
                        phx-click="next_week"
                        class="flex items-center gap-2 bg-white px-3 py-1 text-xs font-medium uppercase tracking-wide text-stone-600 transition hover:bg-stone-50"
                      >
                        Next 7 days
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
                  </:actions>
                </Page.surface>
              </div>

              <Page.surface padding="p-4">
                <:header>
                  <div>
                    <h3 class="text-sm font-semibold text-stone-900">Owner metrics</h3>
                    <p class="text-xs text-stone-500">
                      Service level, safety stock, and reorder point per material at a glance.
                    </p>
                  </div>
                </:header>
                <InventoryComponents.metrics_band
                  id="owner-metrics-band"
                  rows={@forecast_rows}
                  service_level={@service_level}
                  horizon_days={@horizon_days}
                  loading?={!@metrics_loaded?}
                />
                <p :if={@forecast_error} class="mt-3 text-xs text-rose-600">
                  {@forecast_error}
                </p>
              </Page.surface>

              <Page.surface full_bleed class="overflow-hidden">
                <div class="overflow-x-auto">
                  <table class="min-w-[1000px] w-full table-fixed border-collapse">
                    <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
                      <tr>
                        <th class="w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 text-left font-normal">
                          Material
                        </th>
                        <th
                          :for={{day, _index} <- Enum.with_index(@days_range)}
                          class={
                            [
                              "w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 pl-4 font-normal last:border-r-0",
                              is_today?(day) && "bg-indigo-50"
                            ]
                            |> Enum.reject(&is_nil/1)
                          }
                        >
                          <div class="flex items-center justify-center">
                            <div class={[
                              "inline-flex items-center justify-center space-x-1 rounded px-2",
                              is_today?(day) && "bg-indigo-500 text-white"
                            ]}>
                              <div>{format_day_name(day)}</div>
                              <div>{format_short_date(day, @time_zone)}</div>
                            </div>
                          </div>
                        </th>
                        <th class="w-1/7 border-stone-200 p-0 pt-4 pb-4 pl-2 font-normal">
                          Final balance
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
                          class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-left align-top"
                        >
                          <% day_balance = Enum.at(material_data.balance_cells, index) %>
                          <% status = forecast_status(day_quantity, day_balance) %>

                          <div
                            :if={Decimal.compare(day_quantity, Decimal.new(0)) == :gt}
                            class="group relative mt-3 inline-flex"
                          >
                            <button
                              type="button"
                              phx-click="view_material_details"
                              phx-value-date={Date.to_iso8601(day)}
                              phx-value-material={material.id}
                              class={[
                                "inline-flex w-full items-center gap-1 px-2 py-0.5 text-xs font-medium transition focus-visible:ring-primary-400 focus-visible:outline-none focus-visible:ring-2",
                                forecast_status_chip(status)
                              ]}
                            >
                              <div class="grid-row-2 grid">
                                <%!-- <div class="grid-row-2 grid">
                                  <div>Need</div>
                                  <div>{format_amount(material.unit, day_quantity)}</div>
                                </div> --%>
                                <div class="grid-row-2 grid">
                                  <div>{format_amount(material.unit, day_balance)}</div>
                                </div>
                              </div>
                            </button>
                            <div class={[
                              "min-w-[11rem] max-w-[14rem] text-[11px] pointer-events-none absolute top-0 left-0 z-10 hidden -translate-y-full flex-col gap-1 rounded-md border bg-white p-3 shadow-lg ring-1 group-focus-within:flex group-hover:flex",
                              forecast_popover_class(status)
                            ]}>
                              <p class="font-medium text-stone-700">
                                Required {format_amount(material.unit, day_quantity)}
                              </p>
                              <p class="text-stone-600">
                                Projected balance {format_amount(material.unit, day_balance)}
                              </p>
                              <p class={[
                                "text-xs font-semibold",
                                forecast_popover_label_class(status)
                              ]}>
                                {popover_label(status, material.unit, day_quantity, day_balance)}
                              </p>
                            </div>
                          </div>

                          <div
                            :if={Decimal.compare(day_quantity, Decimal.new(0)) != :gt}
                            class="mt-3 text-xs text-stone-300"
                          >
                            —
                          </div>
                        </td>
                        <td class="border-t border-t-stone-200 py-2 pl-2 text-right">
                          {format_amount(
                            material.unit,
                            Map.get(material_data, :weekly_total, material_data.total_quantity)
                          )}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </Page.surface>
            </div>
          </:left>
          <:right>
            <Page.surface padding="p-5">
              <:header>
                <div>
                  <h3 class="text-sm font-semibold text-stone-900">How to read this</h3>
                  <p class="text-xs text-stone-500">
                    Hover a requirement to compare what production needs against projected stock.
                  </p>
                </div>
              </:header>
              <dl class="space-y-4 text-sm text-stone-600">
                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-emerald-200 ring-2 ring-emerald-300" />
                  <div>
                    <dt class="font-medium text-stone-700">Balanced</dt>
                    <dd class="text-xs text-stone-500">
                      Closing balance stays above the required amount. Plenty of stock remains.
                    </dd>
                  </div>
                </div>
                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-amber-200 ring-2 ring-amber-300" />
                  <div>
                    <dt class="font-medium text-stone-700">Watch</dt>
                    <dd class="text-xs text-stone-500">
                      Requirements consume the balance entirely. Confirm replenishment timing.
                    </dd>
                  </div>
                </div>
                <div class="flex items-start gap-3">
                  <span class="mt-1 h-3 w-3 rounded-full bg-rose-200 ring-2 ring-rose-300" />
                  <div>
                    <dt class="font-medium text-rose-600">Shortage</dt>
                    <dd class="text-xs text-stone-500">
                      Requirements exceed available stock. Click the cell to see the orders driving demand.
                    </dd>
                  </div>
                </div>
              </dl>
            </Page.surface>
          </:right>
        </Page.two_column>
      </Page.section>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="material-modal"
        title={@page_title}
        description="Use this form to manage material records in your database."
        show
        on_cancel={JS.patch(~p"/manage/inventory")}
      >
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentMaterial}
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
        title={
        "#{@selected_material.name} for #{format_day_name(@selected_material_date)} #{format_short_date(@selected_material_date, @time_zone)}"
        }
        show
        on_cancel={JS.push("close_material_modal")}
      >
        <div class="py-4">
          <div :if={@material_details && !Enum.empty?(@material_details)} class="space-y-4">
            <.table id="material-products" rows={@material_details}>
              <:col :let={{_product, items}} label="Order References">
                <div class="grid grid-cols-1 gap-1 text-sm">
                  <div :for={item <- items.order_items}>
                    <.link navigate={~p"/manage/orders/#{item.order.reference}"}>
                      <.kbd>
                        {format_reference(item.order.reference)}
                      </.kbd>
                    </.link>
                  </div>
                </div>
              </:col>
              <:col :let={{product, _items}} label="Product">
                <div class="font-medium">{product.name}</div>
              </:col>
              <:col :let={{_product, items}} label="Total Required">
                <div class="text-sm">
                  {format_amount(@selected_material.unit, items.total_quantity)}
                </div>
              </:col>
              <:empty>
                <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-6 text-center text-sm text-stone-500">
                  No product details found for this material
                </div>
              </:empty>
            </.table>
          </div>

          <div
            :if={!@material_details || Enum.empty?(@material_details)}
            class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-8 text-center text-sm text-stone-500"
          >
            No details found for this material on this date
          </div>
        </div>

        <footer class="mt-6 flex items-center justify-end gap-3">
          <.button variant={:outline} phx-click="close_material_modal">Close</.button>
          <.link
            patch={~p"/manage/inventory/#{@selected_material.sku}/adjust"}
            phx-click={JS.push_focus()}
          >
            <.button variant={:primary}>Adjust Stock</.button>
          </.link>
        </footer>
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    today = Date.utc_today()
    socket = assign_forecast_defaults(socket, session)
    days_range = generate_week_range(today, socket.assigns.horizon_days)

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
      |> assign_owner_metrics()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    nav_sub_links = inventory_sub_links(live_action)

    socket =
      socket
      |> assign(:nav_sub_links, nav_sub_links)
      |> apply_action(live_action, params)

    {:noreply, assign(socket, :breadcrumbs, inventory_breadcrumbs(socket.assigns))}
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
    days_range = generate_week_range(today, socket.assigns.horizon_days)
    materials_requirements = prepare_materials_requirements(socket, days_range)

    socket
    |> assign(:page_title, "Inventory Forecast")
    |> assign(:material, nil)
    |> assign(:today, today)
    |> assign(:days_range, days_range)
    |> assign(:materials_requirements, materials_requirements)
    |> assign_owner_metrics()
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
    material = Inventory.get_material_by_id!(material_id, actor: socket.assigns.current_user)

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
        actor: socket.assigns.current_user,
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
    horizon = socket.assigns.horizon_days
    start_date = List.first(socket.assigns.days_range) || socket.assigns.today || Date.utc_today()
    new_start = Date.add(start_date, horizon)
    days_range = generate_week_range(new_start, horizon)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)
     |> assign_owner_metrics()}
  end

  @impl true
  def handle_event("today", _params, socket) do
    # Reset to current day and forward
    today = Date.utc_today()
    days_range = generate_week_range(today, socket.assigns.horizon_days)

    materials_requirements = prepare_materials_requirements(socket, days_range)

    {:noreply,
     socket
     |> assign(:today, today)
     |> assign(:days_range, days_range)
     |> assign(:materials_requirements, materials_requirements)
     |> assign_owner_metrics()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Inventory.get_material_by_id!(actor: socket.assigns.current_user)
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
    material = Ash.load!(material, :current_stock, actor: socket.assigns.current_user)

    {:noreply, stream_insert(socket, :materials, material)}
  end

  defp format_day_name(date) do
    day_of_week = Date.day_of_week(date)
    Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), day_of_week - 1)
  end

  defp forecast_status(day_quantity, balance) do
    cond do
      Decimal.compare(day_quantity, Decimal.new(0)) != :gt -> :none
      Decimal.compare(balance, day_quantity) == :lt -> :shortage
      Decimal.compare(balance, day_quantity) == :eq -> :watch
      Decimal.compare(balance, Decimal.new(0)) == :eq -> :watch
      true -> :balanced
    end
  end

  defp forecast_popover_class(:shortage), do: "border-rose-200 ring-rose-100"
  defp forecast_popover_class(:watch), do: "border-amber-200 ring-amber-100"
  defp forecast_popover_class(:balanced), do: "border-emerald-200 ring-emerald-100"
  defp forecast_popover_class(_), do: "border-stone-200 ring-stone-200"

  defp forecast_popover_label_class(:shortage), do: "text-rose-600"
  defp forecast_popover_label_class(:watch), do: "text-amber-600"
  defp forecast_popover_label_class(:balanced), do: "text-emerald-600"
  defp forecast_popover_label_class(_), do: "text-stone-600"

  defp forecast_status_chip(:shortage), do: "border-rose-200 bg-rose-50 text-rose-700"
  defp forecast_status_chip(:watch), do: "border-amber-200 bg-amber-50 text-amber-700"
  defp forecast_status_chip(:balanced), do: ""
  defp forecast_status_chip(_), do: "border-stone-200 bg-stone-50 text-stone-500"

  defp popover_label(:shortage, unit, required, balance) do
    shortfall = Decimal.max(Decimal.sub(required, balance), Decimal.new(0))
    "Shortage of #{format_amount(unit, shortfall)}"
  end

  defp popover_label(:watch, _unit, _required, _balance), do: "Consumes entire balance"

  defp popover_label(:balanced, unit, required, balance) do
    remaining = Decimal.sub(balance, required)
    "Leaves #{format_amount(unit, remaining)} on hand"
  end

  defp popover_label(_status, unit, _required, balance) do
    "Balance #{format_amount(unit, balance)}"
  end

  defp assign_forecast_defaults(socket, session) do
    prefs = forecast_preferences(session)

    service_level =
      prefs
      |> Map.get("service_level")
      |> normalize_service_level()

    horizon_days =
      prefs
      |> Map.get("horizon_days")
      |> normalize_horizon_days()

    risk_filters =
      prefs
      |> Map.get("risk_filters")
      |> normalize_risk_filters()

    socket
    |> assign(:service_level, service_level)
    |> assign(:horizon_days, horizon_days)
    |> assign(:risk_filters, risk_filters)
    |> assign(:demand_delta, 0)
    |> assign(:lead_time_override, nil)
    |> assign(:metrics_loaded?, false)
    |> assign(:forecast_rows, [])
    |> assign(:forecast_error, nil)
  end

  defp assign_owner_metrics(%{assigns: %{days_range: days_range}} = socket) when days_range in [nil, []] do
    assign(socket, :forecast_rows, [])
  end

  defp assign_owner_metrics(socket) do
    actor = socket.assigns[:current_user]
    days_range = socket.assigns.days_range || []

    socket = assign(socket, :metrics_loaded?, false)

    rows =
      InventoryForecasting.owner_grid_rows(
        days_range,
        [service_level: socket.assigns.service_level],
        actor
      )

    socket
    |> assign(:forecast_rows, rows)
    |> assign(:metrics_loaded?, true)
    |> assign(:forecast_error, nil)
  rescue
    exception ->
      Logger.error("Unable to load forecast metrics: #{Exception.message(exception)}",
        exception: exception,
        stacktrace: __STACKTRACE__
      )

      socket
      |> assign(:forecast_rows, [])
      |> assign(:metrics_loaded?, false)
      |> assign(:forecast_error, "Unable to load forecast metrics right now.")
  end

  defp normalize_service_level(nil), do: @default_service_level

  defp normalize_service_level(%Decimal{} = value) do
    value
    |> Decimal.to_float()
    |> normalize_service_level()
  end

  defp normalize_service_level(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> normalize_service_level(float)
      :error -> @default_service_level
    end
  end

  defp normalize_service_level(value) when is_integer(value) and value > 1 do
    normalize_service_level(value / 100)
  end

  defp normalize_service_level(value) when is_integer(value) do
    normalize_service_level(value * 1.0)
  end

  defp normalize_service_level(value) when is_float(value) do
    allowed_levels = [0.9, 0.95, 0.975, 0.99]

    Enum.min_by(allowed_levels, fn level -> abs(level - value) end)
  end

  defp normalize_horizon_days(nil), do: @default_horizon_days

  defp normalize_horizon_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> normalize_horizon_days(int)
      :error -> @default_horizon_days
    end
  end

  defp normalize_horizon_days(value) when value in [7, 14, 28], do: value
  defp normalize_horizon_days(_value), do: @default_horizon_days

  defp normalize_risk_filters(nil), do: @default_risk_filters

  defp normalize_risk_filters(filters) when is_list(filters) do
    filters
    |> Enum.map(&normalize_risk_filter/1)
    |> Enum.filter(&(&1 in @default_risk_filters))
    |> Enum.uniq()
    |> case do
      [] -> @default_risk_filters
      normalized -> normalized
    end
  end

  defp normalize_risk_filters(_), do: @default_risk_filters

  defp normalize_risk_filter(value) when value in @default_risk_filters, do: value

  defp normalize_risk_filter(value) when is_binary(value) do
    case String.downcase(value) do
      "shortage" -> :shortage
      "watch" -> :watch
      "balanced" -> :balanced
      _ -> nil
    end
  end

  defp normalize_risk_filter(_), do: nil

  defp forecast_preferences(nil), do: %{}

  defp forecast_preferences(session) when is_map(session) do
    Map.get(session, "inventory_forecast_preferences") ||
      Map.get(session, :inventory_forecast_preferences) ||
      %{}
  end

  defp forecast_preferences(_), do: %{}

  defp inventory_sub_links(live_action) do
    [
      %{
        label: "Materials",
        navigate: ~p"/manage/inventory",
        active: live_action in [:index, :new, :edit]
      },
      %{
        label: "Forecast",
        navigate: ~p"/manage/inventory/forecast",
        active: live_action == :forecast
      }
    ]
  end

  defp inventory_breadcrumbs(%{live_action: :index}) do
    [
      %{label: "Inventory", path: ~p"/manage/inventory", current?: true}
    ]
  end

  defp inventory_breadcrumbs(%{live_action: :new}) do
    [
      %{label: "Inventory", path: ~p"/manage/inventory", current?: false},
      %{label: "New Material", path: ~p"/manage/inventory/new", current?: true}
    ]
  end

  defp inventory_breadcrumbs(%{live_action: :forecast}) do
    [
      %{label: "Inventory", path: ~p"/manage/inventory", current?: false},
      %{label: "Forecast", path: ~p"/manage/inventory/forecast", current?: true}
    ]
  end

  defp inventory_breadcrumbs(%{live_action: :edit, material: material}) when not is_nil(material) do
    [
      %{label: "Inventory", path: ~p"/manage/inventory", current?: false},
      %{label: material.name, path: ~p"/manage/inventory/#{material.sku}", current?: true}
    ]
  end

  defp inventory_breadcrumbs(assigns) do
    inventory_breadcrumbs(%{assigns | live_action: :index})
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
    InventoryForecasting.prepare_materials_requirements(days_range, socket.assigns.current_user)
  end
end
