defmodule Craftplan.Repo.Migrations.DropCartTables do
  use Ecto.Migration

  def up do
    drop_if_exists constraint(:cart_items, "cart_items_cart_id_fkey")
    drop_if_exists constraint(:cart_items, "cart_items_product_id_fkey")
    drop_if_exists index(:cart_items, [:cart_id])
    drop_if_exists index(:cart_items, [:product_id])
    drop_if_exists table(:cart_items)

    drop_if_exists table(:cart)
  end

  def down do
    create table(:cart, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :currency, :citext
      add :total_amount, :integer
      add :total_items, :integer
      timestamps(type: :utc_datetime)
    end

    create table(:cart_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :cart_id, references(:cart, type: :uuid, on_delete: :delete_all)
      add :product_id, references(:catalog_products, type: :uuid, on_delete: :nilify_all)
      add :product_name, :text
      add :product_sku, :citext
      add :quantity, :decimal
      add :unit, :citext
      add :unit_price, :decimal
      add :currency, :citext
      add :line_total, :decimal
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
  end
end
