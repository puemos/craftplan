defmodule Craftplan.Repo.Migrations.AddOrganizationIdToProducts do
  use Ecto.Migration

  def change do
    alter table(:catalog_products) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    create index(:catalog_products, [:organization_id])
  end
end
