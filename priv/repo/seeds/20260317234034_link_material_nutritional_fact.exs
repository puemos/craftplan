defmodule Craftplan.Repo.Seeds.LinkMaterialNutritionalFact do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    nutritional_facts = Craftplan.Inventory.list_nutritional_facts!(authorize?: false)

    Enum.each(1..50, fn _ ->
      amount = Enum.random(1..200)
      material = Enum.random(materials)
      nutritional_fact = Enum.random(nutritional_facts)
      unit = Enum.random([:gram, :milligram, :kcal])

      Craftplan.Inventory.MaterialNutritionalFact
      |> Ash.Changeset.for_create(:create, %{
        material_id: material,
        nutritional_fact_id: nutritional_fact,
        amount: Decimal.new(amount),
        unit: unit
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
