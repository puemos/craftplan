defmodule Craftplan.Repo.Seeds.AddNutritionalFacts do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    params = [
      "Calories",
      "Fat",
      "Saturated Fat",
      "Carbohydrates",
      "Sugar",
      "Fiber",
      "Protein",
      "Salt",
      "Sodium",
      "Calcium",
      "Iron",
      "Vitamin A",
      "Vitamin C",
      "Vitamin D"
    ]

    Enum.each(params, fn name ->
      Craftplan.Inventory.NutritionalFact
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create(authorize?: false)
    end)
  end
end
