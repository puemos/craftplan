defmodule Craftplan.Repo.Migrations.AddOneActiveBomPerProduct do
  use Ecto.Migration

  def change do
    create unique_index(:catalog_boms, [:product_id],
             where: "status = 'active'",
             name: "catalog_boms_one_active_per_product"
           )
  end
end

