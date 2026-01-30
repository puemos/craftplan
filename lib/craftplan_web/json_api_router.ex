defmodule CraftplanWeb.JsonApiRouter do
  @moduledoc false
  use AshJsonApi.Router,
    domains: [
      Craftplan.Catalog,
      Craftplan.Orders,
      Craftplan.Inventory,
      Craftplan.CRM,
      Craftplan.Settings
    ],
    open_api: "/open_api"
end
