# seeds.exs

alias Craftplan.Accounts
alias Craftplan.Catalog
alias Craftplan.CRM
alias Craftplan.Inventory
alias Craftplan.Orders
alias Craftplan.Repo
alias Craftplan.Settings

if System.get_env("SEED_DATA") == "true" or (Code.ensure_loaded?(Mix) and Mix.env() == :dev) do
  Repo.delete_all(Orders.ProductionBatchLot)
  Repo.delete_all(Orders.OrderItemBatchAllocation)
  Repo.delete_all(Orders.OrderItemLot)
  Repo.delete_all(Orders.OrderItem)
  Repo.delete_all(Orders.Order)
  Repo.delete_all(Catalog.BOMRollup)
  Repo.delete_all(Catalog.BOMComponent)
  Repo.delete_all(Catalog.LaborStep)
  Repo.delete_all(Catalog.BOM)
  Repo.delete_all(Catalog.Product)
  Repo.delete_all(Inventory.Movement)
  Repo.delete_all(Inventory.Lot)
  Repo.delete_all(Inventory.MaterialNutritionalFact)
  Repo.delete_all(Inventory.NutritionalFact)
  Repo.delete_all(Inventory.MaterialAllergen)
  Repo.delete_all(Inventory.PurchaseOrderItem)
  Repo.delete_all(Inventory.PurchaseOrder)
  Repo.delete_all(Inventory.Supplier)
  Repo.delete_all(Orders.ProductionBatch)
  Repo.delete_all(Inventory.Material)
  Repo.delete_all(Inventory.Allergen)
  Repo.delete_all(CRM.Customer)
  Repo.delete_all(Accounts.User)
  Repo.delete_all(Settings.Settings)

  IO.puts("Database Truncated!")
end

Ash.Seed.seed!(Settings.Settings, %{
  currency: :USD,
  tax_mode: :exclusive,
  tax_rate: Decimal.new("0.10"),
  offers_pickup: true,
  offers_delivery: true,
  lead_time_days: 1,
  daily_capacity: 25,
  shipping_flat: Decimal.new("5.00"),
  labor_hourly_rate: Decimal.new("18.50"),
  labor_overhead_percent: Decimal.new("0.15"),
  retail_markup_mode: :percent,
  retail_markup_value: Decimal.new("35"),
  wholesale_markup_mode: :percent,
  wholesale_markup_value: Decimal.new("20")
})
