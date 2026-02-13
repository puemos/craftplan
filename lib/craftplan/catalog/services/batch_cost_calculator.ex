defmodule Craftplan.Catalog.Services.BatchCostCalculator do
  @moduledoc false

  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.BOMComponent
  alias Craftplan.DecimalHelpers
  alias Craftplan.Settings
  alias Decimal, as: D

  require Catalog

  @spec calculate(BOM.t(), number | Money.t(), keyword) :: %{
          material_cost: Money.t(),
          labor_cost: Money.t(),
          overhead_cost: Money.t(),
          unit_cost: Money.t()
        }
  def calculate(%BOM{} = bom, quantity, opts \\ []) do
    settings = fetch_settings(opts)
    path = MapSet.new()

    do_calculate(bom, DecimalHelpers.to_decimal(quantity), opts, settings, path)
  end

  @spec do_calculate(BOM.t(), D.t(), keyword(), map(), MapSet.t()) :: %{
          material_cost: Money.t(),
          labor_cost: Money.t(),
          overhead_cost: Money.t(),
          unit_cost: Money.t()
        }
  defp do_calculate(%BOM{} = bom, quantity, opts, settings, path) do
    authorize? = Keyword.get(opts, :authorize?, true)
    actor = Keyword.get(opts, :actor)
    currency = Settings.get_settings!().currency

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
      |> Enum.reduce(Money.new!(0, currency), fn component, acc ->
        cost = component_cost(component, quantity, opts, settings, path)
        Money.add!(acc, cost)
      end)

    labor_cost = labor_cost(bom.labor_steps, quantity, settings)
    overhead_cost = overhead_cost(material_cost, labor_cost, settings)

    total_cost =
      material_cost
      |> Money.add!(labor_cost)
      |> Money.add!(overhead_cost)

    unit_cost =
      if D.compare(quantity, D.new(0)) == :gt do
        Money.div!(total_cost, quantity)
      else
        Money.new!(0, currency)
      end

    %{
      material_cost: material_cost,
      labor_cost: labor_cost,
      overhead_cost: overhead_cost,
      unit_cost: unit_cost
    }
  end

  @spec component_cost(BOMComponent.t(), D.t(), keyword(), map(), MapSet.t()) :: D.t()
  defp component_cost(%BOMComponent{component_type: :material} = component, quantity, opts, _settings, _path) do
    currency = Settings.get_settings!().currency
    multiplier = waste_multiplier(component)

    total_quantity =
      quantity |> D.mult(DecimalHelpers.to_decimal(component.quantity)) |> D.mult(multiplier)

    price =
      case component.material do
        %{price: price} -> price
        _ -> Money.new!(0, currency)
      end

    Money.mult!(price, total_quantity)
  end

  defp component_cost(%BOMComponent{component_type: :product} = component, quantity, opts, settings, path) do
    total_quantity =
      quantity
      |> D.mult(DecimalHelpers.to_decimal(component.quantity))
      |> D.mult(waste_multiplier(component))

    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, true)

    with {:ok, product} <- get_product_from_component(component),
         :ok <- check_for_circular_dependency(product.id, path),
         {:ok, bom} <- get_active_bom_for_product(product.id, actor, authorize?) do
      nested_cost = calculate_nested_cost(bom, opts, settings, MapSet.put(path, product.id))
      Money.mult!(nested_cost, total_quantity)
    else
      _error ->
        # Fallback to the product's price if any step fails
        product = Map.get(component, :product)
        fallback_price = Map.get(product, :price)
        Money.mult!(fallback_price, total_quantity)
    end
  end

  defp get_product_from_component(component) do
    case Map.get(component, :product) do
      nil -> {:error, :no_product}
      product -> {:ok, product}
    end
  end

  @spec check_for_circular_dependency(any(), MapSet.t()) :: :ok | {:error, :circular_dependency}
  defp check_for_circular_dependency(product_id, path) do
    if MapSet.member?(path, product_id) do
      {:error, :circular_dependency}
    else
      :ok
    end
  end

  defp get_active_bom_for_product(product_id, actor, authorize?) do
    case Catalog.get_active_bom_for_product(%{product_id: product_id},
           actor: actor,
           authorize?: authorize?
         ) do
      {:ok, bom} when not is_nil(bom) -> {:ok, bom}
      _ -> {:error, :no_active_bom}
    end
  end

  @spec calculate_nested_cost(BOM.t(), keyword(), map(), MapSet.t()) :: D.t()
  defp calculate_nested_cost(bom, opts, settings, path) do
    currency = Settings.get_settings!().currency

    nested =
      do_calculate(
        bom,
        Money.new!(1, currency),
        opts,
        settings,
        path
      )

    nested.unit_cost
  end

  defp waste_multiplier(component) do
    component
    |> Map.get(:waste_percent)
    |> DecimalHelpers.to_decimal()
    |> D.add(D.new(1))
  end

  @spec labor_cost([map()], D.t(), map()) :: D.t()
  defp labor_cost(labor_steps, quantity, settings) do
    base_quantity = DecimalHelpers.to_decimal(quantity)

    labor_steps
    |> Enum.sort_by(& &1.sequence)
    |> Enum.reduce(Money.new(0, settings.currency), fn step, acc ->
      minutes = DecimalHelpers.to_decimal(step.duration_minutes)
      hourly_rate = step.rate_override || settings.labor_hourly_rate
      hours = D.div(minutes, D.new(60))
      per_run_cost = Money.mult!(hourly_rate, hours)

      units_per_run =
        step
        |> Map.get(:units_per_run)
        |> DecimalHelpers.to_decimal()
        |> then(fn value ->
          if D.compare(value, D.new(0)) == :gt, do: value, else: D.new(1)
        end)

      runs = D.div(base_quantity, units_per_run)
      Money.add!(acc, Money.mult!(per_run_cost, D.to_float(runs)))
    end)
  end

  @spec overhead_cost(Money.t(), Money.t(), map()) :: Money.t()
  defp overhead_cost(material_cost, labor_cost, settings) do
    base = Money.add!(material_cost, labor_cost)
    Money.mult!(base, settings.labor_overhead_percent)
  end

  @spec fetch_settings(keyword()) :: map()
  defp fetch_settings(opts) do
    authorize? = Keyword.get(opts, :authorize?, true)
    actor = Keyword.get(opts, :actor)
    currency = Settings.get_settings!().currency

    case Settings.get_settings(actor: actor, authorize?: authorize?) do
      {:ok, nil} ->
        default_settings(currency)

      {:ok, settings} ->
        Map.merge(default_settings(currency), %{
          labor_hourly_rate: settings.labor_hourly_rate,
          labor_overhead_percent: DecimalHelpers.to_decimal(settings.labor_overhead_percent)
        })

      {:error, _} ->
        default_settings(currency)
    end
  end

  defp default_settings(currency) do
    %{
      labor_hourly_rate: Money.new!(0, currency),
      labor_overhead_percent: D.new(0),
      currency: currency
    }
  end

  @spec maybe_track_product(MapSet.t(), any()) :: MapSet.t()
  defp maybe_track_product(path, nil), do: path
  defp maybe_track_product(path, product_id), do: MapSet.put(path, product_id)
end
