defmodule Craftplan.Repo.Migrations.DropRecipeTables do
  use Ecto.Migration

  def change do
    drop_if_exists table(:catalog_recipe_materials)
    drop_if_exists table(:catalog_recipes)
  end
end
