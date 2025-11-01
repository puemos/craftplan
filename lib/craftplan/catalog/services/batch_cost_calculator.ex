defmodule Craftplan.Catalog.Services.BatchCostCalculator do
  @moduledoc false

  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.BOMComponent
  alias Craftplan.DecimalHelpers
  alias Craftplan.Settings
  alias Decimal, as: D

  @spec calculate(BOM.t(), number | D.t(), keyword) :: %{
          material_cost: D.t(),
          labor_cost: D.t(),
          overhead_cost: D.t(),
          unit_cost: D.t()
        }
  def calculate(%BOM{} = bom, quantity, opts \\ []) do
    settings = fetch_settings(opts)
    path = MapSet.new()

    do_calculate(bom, quantity, opts, settings, path)
  end

  defp do_calculate(%BOM{} = bom, quantity, opts, settings, path) do
    authorize? = Keyword.get(opts, :authorize?, true)
    actor = Keyword.get(opts, :actor)

    bom =
      Ash.load!(
        bom,
        [components: [:material, :product], labor_steps: []],
        actor: actor,
        authorize?: authorize?
      )

    quantity = DecimalHelpers.to_decimal(quantity)

    path = maybe_track_product(path, bom.product_id)

    material_cost =
      bom.components
      |> Enum.sort_by(& &1.position)
      |> Enum.reduce(D.new(0), fn component, acc ->
        cost = component_cost(component, quantity, opts, settings, path)
        D.add(acc, cost)
      end)

    labor_cost = labor_cost(bom.labor_steps, quantity, settings)
    overhead_cost = overhead_cost(material_cost, labor_cost, settings)

    total_cost =
      material_cost
      |> D.add(labor_cost)
      |> D.add(overhead_cost)

    unit_cost =
      if D.compare(quantity, D.new(0)) == :gt do
        D.div(total_cost, quantity)
      else
        D.new(0)
      end

    %{
      material_cost: material_cost,
      labor_cost: labor_cost,
      overhead_cost: overhead_cost,
      unit_cost: unit_cost
    }
  end

  defp component_cost(%BOMComponent{component_type: :material} = component, quantity, _opts, _settings, _path) do
    multiplier = waste_multiplier(component)
    total_quantity = quantity |> D.mult(DecimalHelpers.to_decimal(component.quantity)) |> D.mult(multiplier)

    price =
      case component.material do
        %{price: price} -> DecimalHelpers.to_decimal(price)
        _ -> D.new(0)
      end

    D.mult(total_quantity, price)
  end

  defp component_cost(%BOMComponent{component_type: :product} = component, quantity, opts, settings, path) do
    product = Map.get(component, :product)

    case product do
      %{id: product_id} ->
        multiplier = waste_multiplier(component)
        total_quantity = quantity |> D.mult(DecimalHelpers.to_decimal(component.quantity)) |> D.mult(multiplier)

        if MapSet.member?(path, product_id) do
          D.new(0)
        else
          authorize? = Keyword.get(opts, :authorize?, true)
          actor = Keyword.get(opts, :actor)

          case Catalog.get_active_bom_for_product(%{product_id: product_id},
                 actor: actor,
                 authorize?: authorize?
               ) do
            {:ok, bom} when not is_nil(bom) ->
              nested =
                do_calculate(
                  bom,
                  D.new(1),
                  opts,
                  settings,
                  MapSet.put(path, product_id)
                )

              D.mult(total_quantity, nested.unit_cost)

            _ ->
              fallback_price =
                product
                |> Map.get(:price)
                |> DecimalHelpers.to_decimal()

              D.mult(total_quantity, fallback_price)
          end
        end

      _ ->
        D.new(0)
    end
  end

  defp waste_multiplier(component) do
    component
    |> Map.get(:waste_percent)
    |> DecimalHelpers.to_decimal()
    |> D.add(D.new(1))
  end

  defp labor_cost(labor_steps, quantity, settings) do
    base_quantity = DecimalHelpers.to_decimal(quantity)

    labor_steps
    |> Enum.sort_by(& &1.sequence)
    |> Enum.reduce(D.new(0), fn step, acc ->
      minutes = DecimalHelpers.to_decimal(step.duration_minutes)
      hourly_rate = DecimalHelpers.to_decimal(step.rate_override || settings.labor_hourly_rate)
      hours = D.div(minutes, D.new(60))
      per_unit_cost = D.mult(hours, hourly_rate)
      D.add(acc, D.mult(per_unit_cost, base_quantity))
    end)
  end

  defp overhead_cost(material_cost, labor_cost, settings) do
    base = D.add(material_cost, labor_cost)
    D.mult(base, settings.labor_overhead_percent)
  end

  defp fetch_settings(opts) do
    authorize? = Keyword.get(opts, :authorize?, true)
    actor = Keyword.get(opts, :actor)

    case Settings.get_settings(actor: actor, authorize?: authorize?) do
      {:ok, nil} ->
        default_settings()

      {:ok, settings} ->
        Map.merge(default_settings(), %{
          labor_hourly_rate: DecimalHelpers.to_decimal(settings.labor_hourly_rate),
          labor_overhead_percent: DecimalHelpers.to_decimal(settings.labor_overhead_percent)
        })

      {:error, _} ->
        default_settings()
    end
  end

  defp default_settings do
    %{labor_hourly_rate: D.new(0), labor_overhead_percent: D.new(0)}
  end

  defp maybe_track_product(path, nil), do: path
  defp maybe_track_product(path, product_id), do: MapSet.put(path, product_id)
end
