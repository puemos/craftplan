defmodule Craftplan.Repo.Seeds.SeedPurchaseOrder do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    suppliers = Craftplan.Inventory.list_suppliers!(authorize?: false)

    Enum.each(1..25, fn _ ->
      status = Enum.random([:draft, :ordered, :received, :cancelled])
      supplier = Enum.random(suppliers)

      Craftplan.Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{
        supplier_id: supplier.id,
        ordered_at: DateTime.utc_now()
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
