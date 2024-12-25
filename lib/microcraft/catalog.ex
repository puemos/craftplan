defmodule Microcraft.Catalog do
  use Ash.Domain

  resources do
    resource Microcraft.Catalog.Product
    resource Microcraft.Catalog.Recipe
    resource Microcraft.Warehouse.Material
    resource Microcraft.Catalog.RecipeMaterial
  end
end
