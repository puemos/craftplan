defmodule Craftday.Repo.Migrations.AddOrderInvoiceDiscountAndDeliveryFields do
  @moduledoc """
  Adds invoice, discount, and delivery fields to orders.
  """
  use Ecto.Migration

  def up do
    alter table(:orders_orders) do
      add :invoice_number, :text
      add :invoice_status, :text, null: false, default: "none"
      add :invoiced_at, :utc_datetime
      add :payment_method, :text
      add :discount_type, :text, null: false, default: "none"
      add :discount_value, :decimal, null: false, default: "0"
      add :delivery_method, :text, null: false, default: "delivery"
    end
  end

  def down do
    alter table(:orders_orders) do
      remove :delivery_method
      remove :discount_value
      remove :discount_type
      remove :payment_method
      remove :invoiced_at
      remove :invoice_status
      remove :invoice_number
    end
  end
end
