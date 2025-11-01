defmodule Craftplan.Repo.Migrations.DropAdvancedRecipeVersioningFromSettings do
  use Ecto.Migration

  def up do
    alter table(:settings) do
      remove_if_exists :advanced_recipe_versioning
    end
  end

  def down do
    alter table(:settings) do
      add :advanced_recipe_versioning, :boolean, null: false, default: false
    end
  end
end

