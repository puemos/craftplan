defmodule Craftplan.Repo.Migrations.AddTaxAndFulfillmentSettings do
  @moduledoc """
  Adds tax/fulfillment fields to settings.
  """
  use Ecto.Migration

  def up do
    alter table(:settings) do
      add :tax_mode, :text, null: false, default: "exclusive"
      add :tax_rate, :decimal, null: false, default: "0"
      add :offers_pickup, :boolean, null: false, default: true
      add :offers_delivery, :boolean, null: false, default: true
      add :lead_time_days, :integer, null: false, default: 0
      add :daily_capacity, :integer, null: false, default: 0
      add :shipping_flat, :decimal, null: false, default: "0"
    end
  end

  def down do
    alter table(:settings) do
      remove :shipping_flat
      remove :daily_capacity
      remove :lead_time_days
      remove :offers_delivery
      remove :offers_pickup
      remove :tax_rate
      remove :tax_mode
    end
  end
end
