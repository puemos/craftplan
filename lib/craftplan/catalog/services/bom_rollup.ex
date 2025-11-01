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

    components_map = flatten_components(bom, D.new(1), actor: actor, authorize?: authorize?)

    params = %{
      bom_id: bom.id,
      product_id: bom.product_id,
      material_cost: costs.material_cost,
      labor_cost: costs.labor_cost,
      overhead_cost: costs.overhead_cost,
      unit_cost: costs.unit_cost,
      components_map: stringify_decimal_map(components_map)
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

  defp flatten_components(%BOM{} = bom, quantity, opts) do
    authorize? = Keyword.get(opts, :authorize?, false)
    actor = Keyword.get(opts, :actor)

    bom =
      Ash.load!(bom, [components: [:component_type, :quantity, :product, :material]],
        actor: actor,
        authorize?: authorize?
      )

    do_flatten(bom, quantity, MapSet.new(), opts)
  end

  defp do_flatten(%BOM{} = bom, quantity, path, opts) do
    Enum.reduce(bom.components || [], %{}, fn component, acc ->
      case component.component_type do
        :material ->
          mat_id = component.material && component.material.id
          comp_qty = D.mult(quantity, component.quantity || D.new(0))
          Map.update(acc, mat_id, comp_qty, &D.add(&1, comp_qty))

        :product ->
          case component.product do
            %{id: product_id} ->
              if MapSet.member?(path, product_id) do
                acc
              else
                nested_bom =
                  case Craftplan.Catalog.get_active_bom_for_product(%{product_id: product_id},
                         actor: Keyword.get(opts, :actor),
                         authorize?: Keyword.get(opts, :authorize?, false)
                       ) do
                    {:ok, %BOM{} = nested} -> nested
                    _ -> nil
                  end

                if nested_bom do
                  comp_qty = D.mult(quantity, component.quantity || D.new(0))
                  nested_map = do_flatten(nested_bom, comp_qty, MapSet.put(path, product_id), opts)
                  merge_decimal_maps(acc, nested_map)
                else
                  acc
                end
              end

            _ ->
              acc
          end
      end
    end)
  end

  defp merge_decimal_maps(a, b) do
    Map.merge(a, b, fn _k, v1, v2 -> D.add(v1, v2) end)
  end

  defp stringify_decimal_map(map) do
    map
    |> Enum.reject(fn {k, _} -> is_nil(k) end)
    |> Map.new(fn {k, v} -> {k, D.to_string(v)} end)
  end
end
