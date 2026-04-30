defmodule Craftplan.Repo.Seeds.LinkMaterialAllergen do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    allergens = Craftplan.Inventory.list_allergens!(authorize?: false)

    Enum.each(1..50, fn _ ->
      material = Enum.random(materials)
      allergen = Enum.random(allergens)

      Craftplan.Inventory.MaterialAllergen
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        allergen_id: allergen.id
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
