defmodule CraftplanWeb.Components.Inventory do
  @moduledoc """
  Inventory-specific UI components.

  The metrics band component renders the owner-facing forecast grid summary.
  """

  use CraftplanWeb, :html

  alias Decimal, as: D

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
      <div class="flex flex-wrap items-center gap-3 text-xs text-stone-500">
        <span>
          Service level target:
          <span class="font-semibold text-stone-700">{@service_level_label}</span>
        </span>
        <span>
          Horizon: <span class="font-semibold text-stone-700">{@horizon_days}-day view</span>
        </span>
        <span class="text-stone-400">•</span>
        <span class="text-stone-600">
          Suggested PO based on ROP math (on hand + on order + safety stock)
        </span>
      </div>

      <div :if={@loading?} class="rounded-lg border border-dashed border-stone-200 bg-stone-50 p-6">
        <p class="text-sm font-medium text-stone-600">Loading inventory metrics…</p>
      </div>

      <div
        :if={!@loading? && !@has_rows?}
        class="rounded-lg border border-dashed border-stone-200 bg-stone-50 p-6 text-sm text-stone-600"
      >
        No forecast rows available for the selected horizon.
      </div>

      <div :if={!@loading? && @has_rows?} class="-m-4 overflow-x-auto">
        <table class="min-w-[1100px] w-full table-fixed border-collapse text-sm">
          <thead class="bg-stone-50 text-left text-xs font-semibold uppercase tracking-wide text-stone-500">
            <tr>
              <th class="w-48 px-4 py-3 font-semibold">Material</th>
              <th class="w-24 px-4 py-3 text-right font-semibold">On hand</th>
              <th class="w-24 px-4 py-3 text-right font-semibold">On order</th>
              <th class="w-24 px-4 py-3 text-right font-semibold">Avg/day</th>
              <th class="w-28 px-4 py-3 text-right font-semibold">Demand var</th>
              <th class="w-28 px-4 py-3 text-right font-semibold">Lead-time demand</th>
              <th class="w-28 px-4 py-3 text-right font-semibold">Safety stock</th>
              <th class="w-24 px-4 py-3 text-right font-semibold">ROP</th>
              <th class="w-32 px-4 py-3 font-semibold">Cover</th>
              <th class="w-24 px-4 py-3 font-semibold">Stockout</th>
              <th class="w-24 px-4 py-3 font-semibold">Order-by</th>
              <th class="w-32 px-4 py-3 text-right font-semibold">Suggested PO</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-stone-100 text-stone-700">
            <tr :for={row <- @rows} id={"metrics-row-#{row.material_id}"}>
              <td class="px-4 py-3">
                <div class="font-semibold text-stone-900">{row.material_name || "Unassigned"}</div>
                <p class="text-xs text-stone-500">Lead time {row.lead_time_days || 0} days</p>
              </td>
              <td class="font-mono px-4 py-3 text-right text-sm">{decimal_display(row.on_hand)}</td>
              <td class="font-mono px-4 py-3 text-right text-sm">{decimal_display(row.on_order)}</td>
              <td class="font-mono px-4 py-3 text-right text-sm">
                {decimal_display(row.avg_daily_use, places: 2)}
              </td>
              <td class="font-mono px-4 py-3 text-right text-sm">
                {decimal_display(row.demand_variability, places: 2)}
              </td>
              <td class="font-mono px-4 py-3 text-right text-sm">
                {decimal_display(row.lead_time_demand, places: 2)}
              </td>
              <td class="font-mono px-4 py-3 text-right text-sm">
                {decimal_display(row.safety_stock)}
              </td>
              <td class="font-mono px-4 py-3 text-right text-sm">
                {decimal_display(row.reorder_point)}
              </td>
              <td class="px-4 py-3">
                <span class={risk_chip_classes(row.risk_state)}>
                  {cover_label(row.cover_days)}
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-stone-600">{format_date(row.stockout_date)}</td>
              <td class="px-4 py-3 text-sm text-stone-600">{format_date(row.order_by_date)}</td>
              <td class="px-4 py-3 text-right">
                <div class="flex flex-col items-end gap-2">
                  <span class="font-mono text-base font-semibold text-stone-900">
                    {decimal_display(row.suggested_po_qty)}
                  </span>
                  <button
                    type="button"
                    phx-click={@cta_event}
                    phx-value-material-id={row.material_id}
                    phx-target={@phx_target}
                    disabled={cta_disabled?(row, @cta_event)}
                    class="min-w-[8rem] inline-flex w-full items-center justify-center rounded-md border border-stone-200 px-2.5 py-1 text-xs font-semibold uppercase tracking-wide text-stone-700 transition hover:border-stone-300 hover:bg-stone-50 disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    Draft PO
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

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

  defp format_date(nil), do: "—"

  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%m/%d")
  end

  defp risk_chip_classes(nil), do: risk_chip_classes(:balanced)

  defp risk_chip_classes(state) do
    @risk_styles
    |> Map.get(state, @risk_styles.balanced)
    |> Kernel.<>(" inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold ring-1 ring-inset")
  end

  defp cta_disabled?(_row, nil), do: true

  defp cta_disabled?(row, _event) do
    not positive_decimal?(row.suggested_po_qty)
  end

  defp positive_decimal?(%D{} = value), do: D.compare(value, D.new(0)) == :gt
  defp positive_decimal?(value) when is_integer(value), do: value > 0
  defp positive_decimal?(value) when is_float(value), do: value > 0
  defp positive_decimal?(_), do: false

  defp as_decimal(%D{} = value), do: value
  defp as_decimal(value) when is_integer(value), do: D.new(value)
  defp as_decimal(value) when is_float(value), do: D.from_float(value)
  defp as_decimal(_), do: D.new(0)
end
