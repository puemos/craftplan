defmodule Craftplan.Repo.Migrations.AddOrganizationRefsToInventoryAndOrders do
  use Ecto.Migration

  def change do
    alter table(:inventory_materials) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:inventory_suppliers) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:inventory_movements) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:inventory_purchase_orders) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:inventory_purchase_order_items) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:crm_customers) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:orders_orders) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:orders_items) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nilify_all)
    end

    create index(:inventory_materials, [:organization_id])
    create index(:inventory_suppliers, [:organization_id])
    create index(:inventory_movements, [:organization_id])
    create index(:inventory_purchase_orders, [:organization_id])
    create index(:inventory_purchase_order_items, [:organization_id])
    create index(:crm_customers, [:organization_id])
    create index(:orders_orders, [:organization_id])
    create index(:orders_items, [:organization_id])
  end
end
