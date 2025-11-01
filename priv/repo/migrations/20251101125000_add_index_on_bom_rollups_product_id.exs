defmodule Craftplan.Repo.Migrations.AddIndexOnBomRollupsProductId do
  use Ecto.Migration

  def change do
    create index(:catalog_bom_rollups, [:product_id], name: :catalog_bom_rollups_product_id_index)
  end
end

