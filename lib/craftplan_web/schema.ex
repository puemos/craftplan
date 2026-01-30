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

  query do
  end

  mutation do
  end
end
