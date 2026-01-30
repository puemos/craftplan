defmodule Craftplan.Orders.Changes.BatchOpenInit do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Decimal, as: D

  @impl true
  def change(changeset, _opts, _ctx) do
    actor = changeset.context[:private][:actor]

    product_id = Changeset.get_attribute(changeset, :product_id)
    planned_qty = Changeset.get_attribute(changeset, :planned_qty) || D.new(0)

    product =
      Catalog.get_product_by_id!(product_id, actor: actor, load: [active_bom: [:rollup]])

    {bom_id, bom_version, components_map} =
      case product.active_bom do
        %BOM{} = bom ->
          {
            bom.id,
            Map.get(bom, :version),
            (bom.rollup && Map.get(bom.rollup, :components_map)) || %{}
          }

        _ ->
          {nil, nil, %{}}
      end

    code = Craftplan.Production.Batching.generate_batch_code(product.sku, actor)

    changeset
    |> Changeset.force_change_attribute(:batch_code, code)
    |> Changeset.force_change_attribute(:bom_id, bom_id)
    |> Changeset.force_change_attribute(:bom_version, bom_version)
    |> Changeset.force_change_attribute(:components_map, components_map)
    |> Changeset.force_change_attribute(:planned_qty, planned_qty)
    |> Changeset.force_change_attribute(:produced_qty, D.new(0))
    |> Changeset.force_change_attribute(:scrap_qty, D.new(0))
    |> Changeset.force_change_attribute(:status, :open)
  end
end
