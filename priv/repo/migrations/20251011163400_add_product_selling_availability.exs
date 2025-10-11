defmodule Craftday.Repo.Migrations.AddProductSellingAvailability do
  @moduledoc """
  Adds selling_availability to products.
  """
  use Ecto.Migration

  def up do
    alter table(:catalog_products) do
      add :selling_availability, :text, null: false, default: "available"
    end
  end

  def down do
    alter table(:catalog_products) do
      remove :selling_availability
    end
  end
end
