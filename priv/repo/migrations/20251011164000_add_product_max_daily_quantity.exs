defmodule Craftplan.Repo.Migrations.AddProductMaxDailyQuantity do
  @moduledoc """
  Adds max_daily_quantity to catalog_products.
  """
  use Ecto.Migration

  def up do
    alter table(:catalog_products) do
      add :max_daily_quantity, :integer, null: false, default: 0
    end
  end

  def down do
    alter table(:catalog_products) do
      remove :max_daily_quantity
    end
  end
end
