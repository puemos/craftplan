defmodule Craftplan.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Add missing indexes to fix sequential scans causing connection pool exhaustion.

  Findings from pg_stat_user_tables:
  - orders_items: 160,163 seq_scans vs 397 idx_scans
  - inventory_movements: 116,791 seq_scans vs 0 idx_scans
  """
  use Ecto.Migration

  def change do
    # orders_items - most scanned table (160k+ seq scans)
    create_if_not_exists index(:orders_items, [:order_id])
    create_if_not_exists index(:orders_items, [:product_id])
    create_if_not_exists index(:orders_items, [:status])
    create_if_not_exists index(:orders_items, [:production_batch_id])

    # inventory_movements - second most scanned (116k+ seq scans, 0 idx scans)
    create_if_not_exists index(:inventory_movements, [:material_id])
    create_if_not_exists index(:inventory_movements, [:lot_id])
  end
end
