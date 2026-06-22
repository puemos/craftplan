defmodule Craftplan.Inventory.Changes.PreventDestroyWithHistory do
  @moduledoc """
  Block Material destruction when the material is referenced by any other row
  in the system. Without this, deletes pass straight to Postgres and surface
  as foreign-key violations in the logs while the UI only shows a generic
  "failed" flash.

  Six FKs reference inventory_materials; we check all of them and report what's
  blocking the delete:

      catalog_bom_components_material_id_fkey
      inventory_lots_material_id_fkey
      inventory_material_allergen_material_id_fkey
      inventory_material_nutritional_fact_material_id_fkey
      inventory_movements_material_id_fkey
      inventory_purchase_order_items_material_id_fkey

  This change runs as a before_action so the destroy never reaches the DB
  when there's a real reason it shouldn't.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Catalog.BOMComponent
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.MaterialAllergen
  alias Craftplan.Inventory.MaterialNutritionalFact
  alias Craftplan.Inventory.Movement
  alias Craftplan.Inventory.PurchaseOrderItem

  require Ash.Query

  @checks [
    {Movement, "inventory movement"},
    {Lot, "lot"},
    {MaterialAllergen, "allergen association"},
    {MaterialNutritionalFact, "nutritional fact association"},
    {BOMComponent, "BOM component"},
    {PurchaseOrderItem, "purchase order item"}
  ]

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn cs ->
      case cs.data do
        %{id: nil} ->
          cs

        %{id: material_id} ->
          blockers = count_blockers(material_id)

          if Enum.empty?(blockers) do
            cs
          else
            Changeset.add_error(cs, field: :base, message: format_message(blockers))
          end
      end
    end)
  end

  defp count_blockers(material_id) do
    Enum.reduce(@checks, [], fn {resource, label}, acc ->
      count =
        resource
        |> Ash.Query.filter(material_id == ^material_id)
        |> Ash.count!(authorize?: false)

      if count > 0, do: [{count, label} | acc], else: acc
    end)
    |> Enum.reverse()
  end

  defp format_message(blockers) do
    parts =
      blockers
      |> Enum.map(fn {count, label} -> "#{count} #{label}#{plural(count)}" end)
      |> conjoin()

    "Cannot delete: material has #{parts}. Materials with referenced history " <>
      "are kept to preserve the audit trail."
  end

  defp conjoin([single]), do: single
  defp conjoin([a, b]), do: "#{a} and #{b}"

  defp conjoin(list) do
    {init, [last]} = Enum.split(list, -1)
    Enum.join(init, ", ") <> ", and " <> last
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
