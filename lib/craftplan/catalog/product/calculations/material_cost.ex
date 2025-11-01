defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  # Avoid preloading via Calcs; fetch what we need inside
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, _opts, context) do
    actor = context.actor
    authorize? = context.authorize?
    Enum.map(records, &material_cost(&1, actor, authorize?))
  end

  defp material_cost(%{active_bom: %NotLoaded{}, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp material_cost(%{active_bom: nil, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp material_cost(%{active_bom: bom}, _actor, _authorize?) do
    case Map.get(bom, :rollup) do
      %NotLoaded{} -> compute_material_cost(bom)
      nil -> compute_material_cost(bom)
      rollup -> Map.get(rollup, :material_cost) || D.new(0)
    end
  end

  defp fetch_and_compute(product_id, actor, authorize?) do
    case Catalog.get_active_bom_for_product(%{product_id: product_id},
           actor: actor,
           authorize?: authorize?
         ) do
      {:ok, %BOM{} = bom} -> compute_material_cost(bom)
      _ -> D.new(0)
    end
  end

  defp compute_material_cost(bom) do
    bom
    |> BatchCostCalculator.calculate(D.new(1), authorize?: false)
    |> Map.get(:material_cost, D.new(0))
  rescue
    _ -> D.new(0)
  end

  # no recipe fallback
end
