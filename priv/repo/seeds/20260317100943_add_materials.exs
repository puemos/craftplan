defmodule Craftplan.Repo.Seeds.AddMaterials do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    params = [
      ["All Purpose Flour", "FLOUR-001", :gram, "0.002", "5000", "20000"],
      ["Whole Wheat Flour", "FLOUR-002", :gram, "0.003", "3000", "15000"],
      ["Rye Flour", "FLOUR-003", :gram, "0.004", "2000", "8000"],
      ["Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000"],
      ["Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000"],
      ["Whole Almonds", "NUTS-001", :gram, "0.02", "2000", "10000"],
      ["Walnuts", "NUTS-002", :gram, "0.025", "1500", "8000"],
      ["Fresh Eggs", "EGG-001", :piece, "0.15", "100", "500"],
      ["Whole Milk", "MILK-001", :milliliter, "0.003", "2000", "10000"],
      ["Butter", "DAIRY-001", :gram, "0.01", "1000", "5000"],
      ["Cream Cheese", "DAIRY-002", :gram, "0.015", "500", "3000"],
      ["White Sugar", "SUGAR-001", :gram, "0.003", "3000", "15000"],
      ["Brown Sugar", "SUGAR-002", :gram, "0.004", "2000", "10000"],
      ["Dark Chocolate", "CHOC-001", :gram, "0.02", "2000", "8000"],
      ["Vanilla Extract", "FLAV-001", :milliliter, "0.15", "500", "2000"],
      ["Ground Cinnamon", "SPICE-001", :gram, "0.006", "300", "1500"],
      ["Active Dry Yeast", "YEAST-001", :gram, "0.05", "500", "2000"],
      ["Sea Salt", "SALT-001", :gram, "0.001", "1000", "5000"]
    ]

    Enum.each(params, fn [name, sku, unit, price, min, max] ->
      Craftplan.Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price),
        minimum_stock: Decimal.new(min),
        maximum_stock: Decimal.new(max)
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
