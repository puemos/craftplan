defmodule CraftplanWeb.Schema do
  @moduledoc false
  use Absinthe.Schema

  use AshGraphql,
    domains: [
      Craftplan.Catalog,
      Craftplan.Orders,
      Craftplan.Inventory,
      Craftplan.CRM,
      Craftplan.Settings
    ]

  object :money do
    field(:amount, non_null(:decimal))
    field(:currency, non_null(:string))
  end

  input_object :money_input do
    field(:amount, non_null(:decimal))
    field(:currency, non_null(:string))
  end

  query do
  end

  mutation do
  end
end
