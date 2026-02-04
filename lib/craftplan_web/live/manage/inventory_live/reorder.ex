defmodule CraftplanWeb.InventoryLive.ReorderPlanner do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.InventoryForecasting
  alias Craftplan.Settings
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation
  alias Decimal, as: D

  require Logger

  @service_level_options [0.9, 0.95, 0.975, 0.99]
  @horizon_options [7, 14, 28]
  @default_risk_filters [:shortage, :watch, :balanced]

  ## LiveView callbacks

  @impl true
  def render(assigns) do
    ~H"""
    <Page.page>
      <.header>
        Reorder Planner
        <:subtitle>
          Track safety stock, reorder points, and suggested purchase quantities without leaving the dashboard.
        </:subtitle>
        <:actions>
          <.link navigate={~p"/manage/inventory/forecast"}>
            <.button variant={:outline} size={:sm}>View usage forecast</.button>
          </.link>
        </:actions>
      </.header>

      <Page.section>
        <div class="space-y-4">
          <Page.surface>
            <:header>
              <div>
                <h3 class="text-sm font-semibold text-stone-900">Planning controls</h3>
                <p class="text-xs text-stone-500">
                  Adjust service level targets and forecast horizon to refresh the metrics band.
                </p>
              </div>
            </:header>
            <:actions>
              <.button
                type="button"
                variant={:outline}
                size={:sm}
                phx-click="open_forecast_help"
              >
                How to read the metrics band
              </.button>
            </:actions>

            <div class="flex gap-10 space-y-5 text-sm text-stone-600">
              <fieldset>
                <legend class="mb-2 text-xs font-semibold tracking-wide text-stone-500">
                  Service level
                </legend>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={level <- @service_level_options}
                    type="button"
                    phx-click="set_service_level"
                    phx-value-level={level}
                    data-service-level={level}
                    aria-pressed={if(@service_level == level, do: "true", else: "false")}
                    class={toggle_button_classes(@service_level == level)}
                  >
                    {percent_label(level)}
                  </button>
                </div>
              </fieldset>

              <fieldset>
                <legend class="mb-2 text-xs font-semibold tracking-wide text-stone-500">
                  Horizon
                </legend>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={days <- @horizon_options}
                    type="button"
                    phx-click="set_horizon"
                    phx-value-days={days}
                    data-horizon={days}
                    aria-pressed={if(@horizon_days == days, do: "true", else: "false")}
                    class={toggle_button_classes(@horizon_days == days)}
                  >
                    {days}-day
                  </button>
                </div>
              </fieldset>
            </div>

            <div class="mt-2">
              <button
                type="button"
                phx-click="toggle_advanced"
                class="flex w-full items-center justify-between py-3 text-left"
              >
                <div class="flex items-center gap-2">
                  <.icon
                    name={if @advanced_open?, do: "hero-chevron-down", else: "hero-chevron-right"}
                    class="h-4 w-4 text-stone-500"
                  />
                  <span class="text-xs font-semibold text-stone-900">Advanced settings</span>
                  <span class="text-xs text-stone-500">(session only)</span>
                </div>
                <button
                  :if={@advanced_open?}
                  type="button"
                  phx-click="reset_advanced"
                  class="text-xs font-medium text-blue-700 hover:text-blue-800 hover:underline"
                >
                  Reset to defaults
                </button>
              </button>

              <div :if={@advanced_open?} class="border-t border-stone-200 py-4">
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-4">
                  <div>
                    <label class="mb-1 block text-xs font-medium text-stone-600">Lookback days</label>
                    <input
                      type="number"
                      name="lookback_days"
                      value={@lookback_days}
                      min="7"
                      max="365"
                      phx-change="update_advanced"
                      phx-debounce="500"
                      class="w-full rounded-md border border-stone-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-xs font-medium text-stone-600">Actual weight</label>
                    <input
                      type="number"
                      name="actual_weight"
                      value={@actual_weight}
                      min="0"
                      max="1"
                      step="0.01"
                      phx-change="update_advanced"
                      phx-debounce="500"
                      class="w-full rounded-md border border-stone-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-xs font-medium text-stone-600">
                      Planned weight
                    </label>
                    <input
                      type="number"
                      name="planned_weight"
                      value={@planned_weight}
                      min="0"
                      max="1"
                      step="0.01"
                      phx-change="update_advanced"
                      phx-debounce="500"
                      class="w-full rounded-md border border-stone-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-xs font-medium text-stone-600">Min samples</label>
                    <input
                      type="number"
                      name="min_samples"
                      value={@min_samples}
                      min="3"
                      max="100"
                      phx-change="update_advanced"
                      phx-debounce="500"
                      class="w-full rounded-md border border-stone-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                  </div>
                </div>
                <p class="mt-3 text-xs text-stone-500">
                  These settings override your organization defaults for this session only. Changes refresh the forecast automatically.
                </p>
              </div>
            </div>
          </Page.surface>

          <Page.surface full_bleed padding="p-0">
            <.metrics_band
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
        </div>
      </Page.section>

      <.modal
        :if={@show_forecast_help?}
        id="how-to-read-forecast-owner"
        title="How to read the metrics band"
        description="Understand how service level, risk states, and Suggested PO rows connect."
        max_width="max-w-2xl"
        show
        on_cancel={JS.push("close_forecast_help")}
      >
        <div class="space-y-5 text-sm text-stone-600">
          <div>
            <p class="text-sm font-semibold text-stone-700">Service level & horizon</p>
            <p class="text-xs text-stone-500">
              Changing the toggles reruns the calculator with the new buffer target and number of projected days.
              Higher service levels increase safety stock and ROP; longer horizons include more planned demand.
            </p>
          </div>
          <div class="space-y-3">
            <p class="text-sm font-semibold text-stone-700">Risk chips</p>
            <div class="space-y-2 text-xs text-stone-500">
              <div class="flex items-start gap-3">
                <span class="mt-1 h-3 w-3 rounded-full bg-emerald-200 ring-2 ring-emerald-300" />
                <div>
                  <p class="font-medium text-stone-700">Balanced</p>
                  <p>Projected balances stay healthy across the horizon.</p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <span class="mt-1 h-3 w-3 rounded-full bg-amber-200 ring-2 ring-amber-300" />
                <div>
                  <p class="font-medium text-stone-700">Watch</p>
                  <p>Balances drop to zero within the horizon—start planning replenishment.</p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <span class="mt-1 h-3 w-3 rounded-full bg-rose-200 ring-2 ring-rose-300" />
                <div>
                  <p class="font-medium text-rose-600">Shortage</p>
                  <p>Projected balance goes negative. Use the CTA to open a PO draft.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-6 flex justify-end">
          <.button type="button" variant={:outline} phx-click="close_forecast_help">
            Close
          </.button>
        </div>
      </.modal>
    </Page.page>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    today = Date.utc_today()
    settings = safe_get_settings()

    socket =
      socket
      |> assign(:today, today)
      |> assign(:metrics_loaded?, false)
      |> assign(:forecast_rows, [])
      |> assign(:forecast_error, nil)
      |> assign(:service_level_options, @service_level_options)
      |> assign(:horizon_options, @horizon_options)
      |> assign(:show_forecast_help?, false)
      |> assign(:forecast_settings, settings)
      |> assign_forecast_defaults(session, settings)
      |> assign_advanced_defaults(settings)

    {:ok, load_metrics(socket)}
  end

  defp assign_advanced_defaults(socket, settings) do
    socket
    |> assign(:advanced_open?, false)
    |> assign(:lookback_days, Map.get(settings, :forecast_lookback_days) || 42)
    |> assign(
      :actual_weight,
      safe_decimal_to_float(Map.get(settings, :forecast_actual_weight), 0.6)
    )
    |> assign(
      :planned_weight,
      safe_decimal_to_float(Map.get(settings, :forecast_planned_weight), 0.4)
    )
    |> assign(:min_samples, Map.get(settings, :forecast_min_samples) || 10)
  end

  defp safe_decimal_to_float(nil, default), do: default
  defp safe_decimal_to_float(%D{} = decimal, _default), do: D.to_float(decimal)
  defp safe_decimal_to_float(value, _default) when is_float(value), do: value
  defp safe_decimal_to_float(value, _default) when is_integer(value), do: value * 1.0
  defp safe_decimal_to_float(_, default), do: default

  defp safe_get_settings do
    Settings.get_settings!()
  rescue
    _ ->
      %{
        forecast_default_service_level: D.new("0.95"),
        forecast_default_horizon_days: 14,
        forecast_lookback_days: 42,
        forecast_actual_weight: D.new("0.6"),
        forecast_planned_weight: D.new("0.4"),
        forecast_min_samples: 10
      }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, Navigation.assign(socket, :inventory, reorder_trail())}
  end

  @impl true
  def handle_event("set_service_level", %{"level" => level}, socket) do
    {:noreply, refresh_metrics(socket, service_level: normalize_service_level(level))}
  end

  @impl true
  def handle_event("set_horizon", %{"days" => days}, socket) do
    {:noreply, refresh_metrics(socket, horizon_days: normalize_horizon_days(days))}
  end

  @impl true
  def handle_event("open_forecast_help", _params, socket) do
    {:noreply, assign(socket, :show_forecast_help?, true)}
  end

  @impl true
  def handle_event("close_forecast_help", _params, socket) do
    {:noreply, assign(socket, :show_forecast_help?, false)}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :advanced_open?, !socket.assigns.advanced_open?)}
  end

  @impl true
  def handle_event("update_advanced", params, socket) do
    socket =
      socket
      |> maybe_update_lookback_days(params)
      |> maybe_update_actual_weight(params)
      |> maybe_update_planned_weight(params)
      |> maybe_update_min_samples(params)

    {:noreply, load_metrics(socket)}
  end

  @impl true
  def handle_event("reset_advanced", _params, socket) do
    settings = socket.assigns.forecast_settings

    socket =
      socket
      |> assign(:lookback_days, Map.get(settings, :forecast_lookback_days) || 42)
      |> assign(
        :actual_weight,
        safe_decimal_to_float(Map.get(settings, :forecast_actual_weight), 0.6)
      )
      |> assign(
        :planned_weight,
        safe_decimal_to_float(Map.get(settings, :forecast_planned_weight), 0.4)
      )
      |> assign(:min_samples, Map.get(settings, :forecast_min_samples) || 10)

    {:noreply, load_metrics(socket)}
  end

  defp maybe_update_lookback_days(socket, %{"lookback_days" => value}) do
    case Integer.parse(value) do
      {days, _} when days >= 7 and days <= 365 -> assign(socket, :lookback_days, days)
      _ -> socket
    end
  end

  defp maybe_update_lookback_days(socket, _), do: socket

  defp maybe_update_actual_weight(socket, %{"actual_weight" => value}) do
    case Float.parse(value) do
      {weight, _} when weight >= 0 and weight <= 1 -> assign(socket, :actual_weight, weight)
      _ -> socket
    end
  end

  defp maybe_update_actual_weight(socket, _), do: socket

  defp maybe_update_planned_weight(socket, %{"planned_weight" => value}) do
    case Float.parse(value) do
      {weight, _} when weight >= 0 and weight <= 1 -> assign(socket, :planned_weight, weight)
      _ -> socket
    end
  end

  defp maybe_update_planned_weight(socket, _), do: socket

  defp maybe_update_min_samples(socket, %{"min_samples" => value}) do
    case Integer.parse(value) do
      {samples, _} when samples >= 3 and samples <= 100 -> assign(socket, :min_samples, samples)
      _ -> socket
    end
  end

  defp maybe_update_min_samples(socket, _), do: socket

  ## Metrics loading

  defp refresh_metrics(socket, assigns) do
    socket
    |> assign(assigns)
    |> load_metrics()
  end

  defp load_metrics(%{assigns: %{horizon_days: horizon}} = socket) when horizon <= 0 do
    socket
  end

  defp load_metrics(socket) do
    days_range = build_days_range(socket.assigns.today, socket.assigns.horizon_days)
    actor = socket.assigns[:current_user]

    socket = assign(socket, :metrics_loaded?, false)

    opts = [
      service_level: socket.assigns.service_level,
      lookback_days: socket.assigns.lookback_days,
      actual_weight: socket.assigns.actual_weight,
      planned_weight: socket.assigns.planned_weight,
      min_samples: socket.assigns.min_samples
    ]

    rows = InventoryForecasting.owner_grid_rows(days_range, opts, actor)

    socket
    |> assign(:forecast_rows, rows)
    |> assign(:metrics_loaded?, true)
    |> assign(:forecast_error, nil)
    |> assign(:days_range, days_range)
  rescue
    exception ->
      Logger.error("Unable to load owner forecast metrics: #{Exception.message(exception)}",
        exception: exception,
        stacktrace: __STACKTRACE__
      )

      socket
      |> assign(:forecast_rows, [])
      |> assign(:metrics_loaded?, false)
      |> assign(:forecast_error, "Unable to load forecast metrics right now.")
  end

  defp build_days_range(start_date, days) when days > 0 do
    Enum.map(0..(days - 1), fn offset -> Date.add(start_date, offset) end)
  end

  defp build_days_range(_, _), do: []

  ## Preference defaults

  defp assign_forecast_defaults(socket, session, settings) do
    prefs = forecast_preferences(session)

    default_service_level = settings_service_level(settings)
    default_horizon_days = settings_horizon_days(settings)

    defaults = [
      service_level: prefs |> Map.get("service_level") |> normalize_service_level(default_service_level),
      horizon_days: prefs |> Map.get("horizon_days") |> normalize_horizon_days(default_horizon_days),
      risk_filters: prefs |> Map.get("risk_filters") |> normalize_risk_filters()
    ]

    assign(socket, defaults)
  end

  defp settings_service_level(%{forecast_default_service_level: %D{} = level}) do
    D.to_float(level)
  end

  defp settings_service_level(_), do: 0.95

  defp settings_horizon_days(%{forecast_default_horizon_days: days}) when is_integer(days), do: days

  defp settings_horizon_days(_), do: 14

  ## Normalization

  defp normalize_service_level(value, default \\ 0.95)

  defp normalize_service_level(nil, default), do: snap_to_service_level(default)

  defp normalize_service_level(%D{} = value, default) do
    value
    |> D.to_float()
    |> normalize_service_level(default)
  end

  defp normalize_service_level(value, default) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> normalize_service_level(float, default)
      :error -> snap_to_service_level(default)
    end
  end

  defp normalize_service_level(value, default) when is_integer(value) and value > 1 do
    normalize_service_level(value / 100, default)
  end

  defp normalize_service_level(value, default) when is_integer(value) do
    normalize_service_level(value * 1.0, default)
  end

  defp normalize_service_level(value, _default) when is_float(value) do
    snap_to_service_level(value)
  end

  defp snap_to_service_level(value) do
    Enum.min_by(@service_level_options, fn level -> abs(level - value) end)
  end

  defp normalize_horizon_days(value, default \\ 14)

  defp normalize_horizon_days(nil, default), do: snap_to_horizon(default)

  defp normalize_horizon_days(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> normalize_horizon_days(int, default)
      :error -> snap_to_horizon(default)
    end
  end

  defp normalize_horizon_days(value, _default) when value in @horizon_options, do: value
  defp normalize_horizon_days(_, default), do: snap_to_horizon(default)

  defp snap_to_horizon(value) when value in @horizon_options, do: value

  defp snap_to_horizon(value) when is_integer(value) do
    Enum.min_by(@horizon_options, fn opt -> abs(opt - value) end)
  end

  defp snap_to_horizon(_), do: 14

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

  ## Navigation

  defp reorder_trail do
    [
      Navigation.root(:inventory),
      Navigation.page(:inventory, :reorder)
    ]
  end

  ## Metrics band component

  @risk_styles %{
    shortage: "bg-rose-50 text-rose-700 ring-rose-200",
    watch: "bg-amber-50 text-amber-700 ring-amber-200",
    balanced: "bg-emerald-50 text-emerald-700 ring-emerald-200"
  }

  attr :id, :string, default: "inventory-metrics-band"
  attr :rows, :list, default: []
  attr :service_level, :float, default: 0.95
  attr :horizon_days, :integer, default: 7
  attr :loading?, :boolean, default: false
  attr :cta_event, :string, default: nil
  attr :phx_target, :any, default: nil

  def metrics_band(assigns) do
    assigns =
      assigns
      |> assign_new(:service_level_label, fn -> percent_label(assigns.service_level) end)
      |> assign_new(:has_rows?, fn -> Enum.any?(assigns.rows) end)

    ~H"""
    <div id={@id} class="space-y-3">
      <div :if={@loading?} class="rounded-lg border border-dashed border-stone-200 bg-stone-50 p-6">
        <p class="text-sm font-medium text-stone-600">Loading inventory metrics…</p>
      </div>

      <div
        :if={!@loading? && !@has_rows?}
        class="rounded-lg border border-dashed border-stone-200 bg-stone-50 p-6 text-sm text-stone-600"
      >
        No forecast rows available for the selected horizon.
      </div>

      <.scroll_table
        :if={!@loading? && @has_rows?}
        id="owner-metrics-band-shell"
        min_width="min-w-[1300px]"
      >
        <table class="w-full table-fixed border-collapse text-sm">
          <thead class="bg-stone-50 text-left text-xs font-semibold tracking-wide text-stone-500">
            <tr>
              <th class="sticky left-0 z-20 w-48 border-r border-stone-200 bg-white p-3 text-left">
                Material
              </th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">
                On hand
              </th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">
                On order
              </th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">
                Avg/day
              </th>
              <th class="w-28 border-r border-stone-200 p-3 text-center font-normal">
                Demand var
              </th>
              <th class="w-40 border-r border-stone-200 p-3 text-center font-normal">
                Lead-time demand
              </th>
              <th class="w-28 border-r border-stone-200 p-3 text-center font-normal">
                Safety stock
              </th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">ROP</th>
              <th class="w-40 border-r border-stone-200 p-3 text-center font-normal">Cover</th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">
                Stockout
              </th>
              <th class="w-24 border-r border-stone-200 p-3 text-center font-normal">
                Order-by
              </th>
              <th class="w-32 border-r border-stone-200 p-3 text-center font-normal">
                Suggested PO
              </th>
              <th class="w-32 p-3 text-right font-normal">Action</th>
            </tr>
          </thead>

          <tbody class="text-stone-700">
            <tr
              :for={row <- @rows}
              id={"metrics-row-#{row.material_id}"}
              class="border-t border-stone-200"
            >
              <td class="sticky left-0 z-10 border-r border-stone-200 bg-white px-3 py-2 text-left font-medium shadow-sm">
                {row.material_name || "Unassigned"}
              </td>

              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.on_hand)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.on_order)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.avg_daily_use, places: 2)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.demand_variability, places: 2)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.lead_time_demand, places: 2)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.safety_stock)}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                {decimal_display(row.reorder_point)}
              </td>

              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-left last:border-r-0">
                <span class={risk_chip_classes(row.risk_state)}>
                  {cover_label(row.cover_days)}
                </span>
              </td>

              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-left text-stone-600 last:border-r-0">
                {format_short_date(row.stockout_date, missing: "—")}
              </td>
              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-left text-stone-600 last:border-r-0">
                {format_short_date(row.order_by_date, missing: "—")}
              </td>

              <td class="relative border-t border-r border-t-stone-200 border-r-stone-200 p-3 text-right last:border-r-0">
                <span class="font-semibold text-stone-900">
                  {decimal_display(row.suggested_po_qty)}
                </span>
              </td>

              <td class="relative border-t border-t-stone-200 p-3 text-right">
                <.button
                  type="button"
                  size={:sm}
                  phx-click={@cta_event}
                  phx-value-material-id={row.material_id}
                  phx-target={@phx_target}
                  disabled={cta_disabled?(row, @cta_event)}
                >
                  Draft PO
                </.button>
              </td>
            </tr>
          </tbody>
        </table>
      </.scroll_table>
    </div>
    """
  end

  ## UI helpers

  defp toggle_button_classes(true),
    do: "rounded-md border border-stone-300 bg-stone-900 px-3 py-1 text-xs font-semibold tracking-wide text-white shadow"

  defp toggle_button_classes(false),
    do:
      "rounded-md border border-stone-200 bg-white px-3 py-1 text-xs font-semibold tracking-wide text-stone-600 transition hover:border-stone-300 hover:bg-stone-50"

  defp percent_label(nil), do: percent_label(0.95)
  defp percent_label(%D{} = value), do: percent_label(D.to_float(value))

  defp percent_label(value) when is_float(value) or is_integer(value) do
    value
    |> as_decimal()
    |> D.mult(100)
    |> D.round(1)
    |> D.to_string(:normal)
    |> Kernel.<>("%")
  end

  defp decimal_display(value, opts \\ [])
  defp decimal_display(nil, _opts), do: "—"

  defp decimal_display(value, opts) when is_integer(value), do: decimal_display(D.new(value), opts)

  defp decimal_display(value, opts) when is_float(value), do: decimal_display(D.from_float(value), opts)

  defp decimal_display(%D{} = value, opts) do
    places = Keyword.get(opts, :places, 1)

    value
    |> D.round(places)
    |> D.to_string(:normal)
  end

  defp cover_label(nil), do: "—"

  defp cover_label(%D{} = value) do
    value
    |> D.round(1)
    |> D.to_string(:normal)
    |> Kernel.<>(" days cover")
  end

  defp cover_label(value) when is_number(value) do
    value
    |> as_decimal()
    |> cover_label()
  end

  defp risk_chip_classes(nil), do: risk_chip_classes(:balanced)

  defp risk_chip_classes(state) do
    @risk_styles
    |> Map.get(state, @risk_styles.balanced)
    |> Kernel.<>(" inline-flex items-center px-2.5 py-1 text-[11px] font-semibold ring-1 ring-inset")
  end

  defp cta_disabled?(_row, nil), do: true

  defp cta_disabled?(row, _event) do
    not positive_decimal?(row.suggested_po_qty)
  end

  defp positive_decimal?(%D{} = value), do: D.compare(value, D.new(0)) == :gt
  defp positive_decimal?(value) when is_integer(value), do: value > 0
  defp positive_decimal?(value) when is_float(value), do: value > 0
  defp positive_decimal?(_), do: false

  defp as_decimal(value) when is_integer(value), do: D.new(value)
  defp as_decimal(value) when is_float(value), do: D.from_float(value)
end
