defmodule Craftplan.Repo.Seeds.AddInitialStock do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    Enum.each(Craftplan.Inventory.list_materials!(authorize?: false), fn material ->
      quantity = Enum.random(1..200)

      Craftplan.Inventory.Movement
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Initial stock"
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
