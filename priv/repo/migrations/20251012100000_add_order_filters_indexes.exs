defmodule Craftplan.Repo.Migrations.AddOrderFiltersIndexes do
  use Ecto.Migration

  def up do
    create index(:orders_orders, [:delivery_date])
    create index(:orders_orders, [:status])
    create index(:orders_orders, [:payment_status])
  end

  def down do
    drop_if_exists index(:orders_orders, [:payment_status])
    drop_if_exists index(:orders_orders, [:status])
    drop_if_exists index(:orders_orders, [:delivery_date])
  end
end
