defmodule Craftplan.Repo.Seeds.SeedProduct do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    params = [
      ["Almond Cookies", "COOK-001", "3.99"],
      ["Chocolate Cake", "CAKE-001", "15.99"],
      ["Artisan Bread", "BREAD-001", "4.99"],
      ["Blueberry Muffins", "MUF-001", "2.99"],
      ["Butter Croissants", "PAST-001", "2.50"],
      ["Gluten-Free Cupcakes", "CUP-001", "3.49"],
      ["Rye Loaf Bread", "BREAD-002", "5.49"],
      ["Carrot Cake", "CAKE-002", "12.99"],
      ["Oatmeal Cookies", "COOK-002", "3.49"],
      ["Cheese Danish", "PAST-002", "2.99"]
    ]

    Enum.each(params, fn [name, sku, price] ->
      Craftplan.Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        status: :active,
        price: Decimal.new(price)
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
