defmodule Craftplan.Catalog.Product.Calculations.Allergens do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Craftplan.Catalog.Services.BOMRollup
  alias Craftplan.Inventory.Material

  require Ash.Query

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:active_bom]
  end

  @impl true
  def calculate(records, _opts, context) do
    opts = [actor: context.actor, authorize?: context.authorize?]

    Enum.map(records, fn record ->
      case record.active_bom do
        %Ash.NotLoaded{} -> []
        nil -> []
        bom -> allergen_list_from_bom(bom, opts)
      end
    end)
  end

  defp allergen_list_from_bom(bom, opts) do
    material_ids = bom |> BOMRollup.flatten_components(Decimal.new(1), opts) |> Map.keys()

    Material
    |> Ash.Query.filter(id in ^material_ids)
    |> Ash.Query.load(allergens: [:name])
    |> Ash.read!(opts)
    |> Enum.flat_map(& &1.allergens)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end
end
