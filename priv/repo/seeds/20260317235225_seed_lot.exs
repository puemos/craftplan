defmodule Craftplan.Repo.Seeds.SeedLot do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    suppliers = Craftplan.Inventory.list_suppliers!(authorize?: false)

    Enum.each(1..50, fn _ ->
      quantity = Enum.random(1..200)
      material = Enum.random(materials)
      supplier = Enum.random(suppliers)
      expiry_in_days = Enum.random(1..14)
      lot_code = "LOT#{material.name}_#{Date.to_string(Date.utc_today())}_#{Enum.random(1..14)}"

      lot =
        Craftplan.Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: lot_code,
          material_id: material.id,
          supplier_id: supplier && supplier.id,
          received_at: DateTime.utc_now(),
          expiry_date: Date.add(Date.utc_today(), expiry_in_days)
        })
        |> Ash.create(authorize?: false)

      Craftplan.Inventory.Movement
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        lot_id: lot.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Received lot #{lot_code}"
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
