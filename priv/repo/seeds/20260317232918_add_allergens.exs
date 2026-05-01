defmodule Craftplan.Repo.Seeds.AddAllergens do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    params = [
      "Gluten",
      "Fish",
      "Milk",
      "Mustard",
      "Lupin",
      "Crustaceans",
      "Peanuts",
      "Tree Nuts",
      "Sesame",
      "Mollusks",
      "Eggs",
      "Soy",
      "Celery",
      "Sulphur Dioxide"
    ]

    Enum.each(params, fn name ->
      Craftplan.Inventory.Allergen
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create(authorize?: false)
    end)
  end
end
