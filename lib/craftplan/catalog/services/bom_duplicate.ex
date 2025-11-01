defmodule Craftplan.Catalog.Services.BOMDuplicate do
  @moduledoc false

  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM

  def duplicate!(%BOM{} = bom, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    bom = Ash.load!(bom, [components: [:component_type, :quantity, :position, :waste_percent, :notes, :material_id, :product_id], labor_steps: [:name, :sequence, :duration_minutes, :rate_override, :notes]], actor: actor, authorize?: authorize?)

    components =
      Enum.map(bom.components || [], fn c ->
        %{
          component_type: c.component_type,
          quantity: c.quantity,
          position: c.position,
          waste_percent: c.waste_percent,
          notes: c.notes,
          material_id: c.material_id,
          product_id: c.product_id
        }
      end)

    labor_steps =
      Enum.map(bom.labor_steps || [], fn s ->
        %{
          name: s.name,
          sequence: s.sequence,
          duration_minutes: s.duration_minutes,
          rate_override: s.rate_override,
          notes: s.notes
        }
      end)

    Catalog.BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: bom.product_id,
      name: (bom.name && (bom.name <> " (Copy)")) || "BOM Copy",
      status: :draft,
      components: components,
      labor_steps: labor_steps
    })
    |> Ash.create!(actor: actor, authorize?: authorize?)
  end
end

