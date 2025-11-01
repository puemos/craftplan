defmodule Craftplan.Catalog.Services.BOMRollup do
  @moduledoc false

  import Ash.Expr

  alias Ash.Query
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.BOMRollup
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Decimal, as: D

  require Query

  @spec refresh!(BOM.t(), keyword) :: :ok
  def refresh!(%BOM{} = bom, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    bom = Ash.load!(bom, [:product_id], actor: actor, authorize?: authorize?)

    costs =
      BatchCostCalculator.calculate(bom, D.new(1),
        actor: actor,
        authorize?: authorize?
      )

    params = %{
      bom_id: bom.id,
      product_id: bom.product_id,
      material_cost: costs.material_cost,
      labor_cost: costs.labor_cost,
      overhead_cost: costs.overhead_cost,
      unit_cost: costs.unit_cost
    }

    case get_rollup(bom, actor, authorize?) do
      nil ->
        BOMRollup
        |> Ash.Changeset.for_create(:create, params)
        |> Ash.create(actor: actor, authorize?: authorize?)

      %BOMRollup{} = rollup ->
        rollup
        |> Ash.Changeset.for_update(:update, Map.drop(params, [:bom_id, :product_id]))
        |> Ash.update(actor: actor, authorize?: authorize?)
    end

    :ok
  end

  def refresh_by_bom_id!(bom_id, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    case Ash.get(BOM, bom_id, actor: actor, authorize?: authorize?) do
      {:ok, bom} -> refresh!(bom, opts)
      _ -> :ok
    end
  end

  defp get_rollup(bom, actor, authorize?) do
    id = bom.id

    BOMRollup
    |> Query.new()
    |> Query.filter(expr(bom_id == ^id))
    |> Ash.read_one(actor: actor, authorize?: authorize?)
    |> case do
      {:ok, %BOMRollup{} = rollup} -> rollup
      _ -> nil
    end
  end
end
