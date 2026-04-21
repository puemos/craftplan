defmodule Craftplan.Repo.Seeds.SeedPurchaseOrderItem do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    po = Craftplan.Inventory.list_purchase_orders!(authorize?: false)

    Enum.each(1..25, fn _ ->
      material = Enum.random(materials)
      po = Enum.random(po)
      quantity = Enum.random(1..200)
      unit_price = Enum.random(1..200)

      Craftplan.Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: material.id,
        quantity: Decimal.new(quantity),
        unit_price: Decimal.new(unit_price)
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
