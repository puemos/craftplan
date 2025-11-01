defmodule Craftplan.Repo.Migrations.AddComponentsMapToBomRollups do
  use Ecto.Migration

  def change do
    alter table(:catalog_bom_rollups) do
      add :components_map, :map, null: false, default: %{}
    end

    execute "CREATE INDEX IF NOT EXISTS catalog_bom_rollups_components_map_gin ON catalog_bom_rollups USING GIN (components_map)"
  end
end

