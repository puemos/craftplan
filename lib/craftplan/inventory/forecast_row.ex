defmodule Craftplan.Inventory.ForecastRow do
  @moduledoc """
  Embedded Ash resource used to surface inventory forecast grid metrics.
  """

  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  alias Craftplan.Inventory.ForecastRow.ReadOwnerMetrics

  actions do
    read :owner_grid_metrics do
      argument :rows, {:array, :map} do
        allow_nil? false
        constraints min_length: 0
      end

      manual ReadOwnerMetrics
    end
  end

  attributes do
    attribute :material_id, :uuid, public?: true, allow_nil?: true
    attribute :material_name, :string, public?: true, allow_nil?: true

    attribute :on_hand, :decimal, public?: true, allow_nil?: false, default: Decimal.new(0)
    attribute :on_order, :decimal, public?: true, allow_nil?: false, default: Decimal.new(0)
    attribute :lead_time_days, :integer, public?: true, allow_nil?: false, default: 0

    attribute :service_level_z, :decimal,
      public?: true,
      allow_nil?: false,
      default: Decimal.from_float(1.65)

    attribute :pack_size, :decimal, public?: true, allow_nil?: false, default: Decimal.new(1)
    attribute :max_cover_days, :integer, public?: true, allow_nil?: true

    attribute :avg_daily_use, :decimal, public?: true, allow_nil?: false, default: Decimal.new(0)

    attribute :demand_variability, :decimal,
      public?: true,
      allow_nil?: false,
      default: Decimal.new(0)

    attribute :lead_time_demand, :decimal,
      public?: true,
      allow_nil?: false,
      default: Decimal.new(0)

    attribute :safety_stock, :decimal, public?: true, allow_nil?: false, default: Decimal.new(0)
    attribute :reorder_point, :decimal, public?: true, allow_nil?: false, default: Decimal.new(0)
    attribute :cover_days, :decimal, public?: true, allow_nil?: true
    attribute :stockout_date, :date, public?: true, allow_nil?: true
    attribute :order_by_date, :date, public?: true, allow_nil?: true

    attribute :suggested_po_qty, :decimal,
      public?: true,
      allow_nil?: false,
      default: Decimal.new(0)

    attribute :risk_state, :atom, public?: true, allow_nil?: false, default: :balanced

    attribute :projected_balances, {:array, :map},
      public?: true,
      allow_nil?: false,
      default: []

    attribute :actual_usage, {:array, :decimal}, public?: false, allow_nil?: false, default: []
    attribute :planned_usage, {:array, :decimal}, public?: false, allow_nil?: false, default: []
  end

  @doc false
  defmodule ReadOwnerMetrics do
    @moduledoc false
    use Ash.Resource.ManualRead

    alias Craftplan.Inventory.ForecastMetrics

    @allowed_keys [
      :material_id,
      :material_name,
      :on_hand,
      :on_order,
      :lead_time_days,
      :service_level_z,
      :pack_size,
      :max_cover_days,
      :actual_usage,
      :planned_usage,
      :projected_balances
    ]

    @allowed_key_strings MapSet.new(Enum.map(@allowed_keys, &Atom.to_string/1))

    @impl true
    def read(query, _data_layer_query, _opts, _context) do
      rows =
        query.arguments
        |> Map.get(:rows, [])
        |> Enum.map(&ensure_atom_keys/1)

      rows
      |> Enum.map(&build_row(query.resource, &1))
      |> then(&{:ok, &1})
    end

    defp build_row(resource, row) do
      actual_usage = Map.get(row, :actual_usage, [])
      planned_usage = Map.get(row, :planned_usage, [])
      projected_balances = normalize_projections(Map.get(row, :projected_balances, []))

      on_hand = Map.get(row, :on_hand, 0)
      on_order = Map.get(row, :on_order, 0)
      lead_time_days = Map.get(row, :lead_time_days, 0)
      service_level_z = Map.get(row, :service_level_z, 1.65)
      pack_size = Map.get(row, :pack_size, 1)
      max_cover_days = Map.get(row, :max_cover_days)

      avg_daily_use = ForecastMetrics.avg_daily_use(actual_usage, planned_usage)
      demand_variability = ForecastMetrics.demand_variability(actual_usage, planned_usage)
      lead_time_demand = ForecastMetrics.lead_time_demand(avg_daily_use, lead_time_days)

      safety_stock =
        ForecastMetrics.safety_stock(
          decimal_from_number(service_level_z),
          demand_variability,
          lead_time_days
        )

      reorder_point = ForecastMetrics.reorder_point(lead_time_demand, safety_stock)
      cover_days = ForecastMetrics.cover_days(on_hand, avg_daily_use)
      stockout_date = ForecastMetrics.stockout_date(projected_balances)
      order_by_date = ForecastMetrics.order_by_date(stockout_date, lead_time_days)

      suggested_po_qty =
        ForecastMetrics.suggested_po_qty(
          reorder_point,
          on_hand,
          on_order,
          pack_size: pack_size,
          avg_daily_use: avg_daily_use,
          max_cover_days: max_cover_days
        )

      risk_state = ForecastMetrics.risk_state(projected_balances)

      attrs = %{
        material_id: Map.get(row, :material_id),
        material_name: Map.get(row, :material_name),
        on_hand: decimal_from_number(on_hand),
        on_order: decimal_from_number(on_order),
        lead_time_days: lead_time_days,
        service_level_z: decimal_from_number(service_level_z),
        pack_size: decimal_from_number(pack_size),
        max_cover_days: max_cover_days,
        avg_daily_use: avg_daily_use,
        demand_variability: demand_variability,
        lead_time_demand: lead_time_demand,
        safety_stock: safety_stock,
        reorder_point: reorder_point,
        cover_days: cover_days,
        stockout_date: stockout_date,
        order_by_date: order_by_date,
        suggested_po_qty: suggested_po_qty,
        risk_state: risk_state,
        projected_balances: balance_maps(projected_balances),
        actual_usage: decimal_list(actual_usage),
        planned_usage: decimal_list(planned_usage)
      }

      struct(resource, attrs)
    end

    defp ensure_atom_keys(value) when is_map(value) do
      Map.new(value, fn {key, val} -> {atomize(key), val} end)
    end

    defp ensure_atom_keys(value), do: value

    defp atomize(key) when is_atom(key), do: key

    defp atomize(key) when is_binary(key) do
      if MapSet.member?(@allowed_key_strings, key) do
        String.to_existing_atom(key)
      else
        key
      end
    rescue
      ArgumentError ->
        key
    end

    defp normalize_projections(projections) do
      Enum.map(projections, fn
        %{date: date, balance: balance} -> {date, balance}
        %{date: date, projected_balance: balance} -> {date, balance}
        {date, balance} -> {date, balance}
      end)
    end

    defp balance_maps(projections) do
      Enum.map(projections, fn {date, balance} ->
        %{date: date, balance: decimal_from_number(balance)}
      end)
    end

    defp decimal_list(values) do
      Enum.map(values, &decimal_from_number/1)
    end

    defp decimal_from_number(%Decimal{} = decimal), do: decimal
    defp decimal_from_number(value) when is_integer(value), do: Decimal.new(value)

    defp decimal_from_number(value) when is_float(value) do
      value
      |> Float.round(10)
      |> Decimal.from_float()
    end

    defp decimal_from_number(value) when is_binary(value), do: Decimal.new(value)
    defp decimal_from_number(nil), do: Decimal.new(0)
  end
end
