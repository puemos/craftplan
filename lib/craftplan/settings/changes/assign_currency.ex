defmodule Craftplan.Settings.Changes.AssignCurrency do
  @moduledoc """
  Change the currency type in the following schemas due to using the sum procedure (we cant sum 2 different currency types)
  [catalog_bom_rollups, catalog_labor_steps, catalog_products, inventory_materials, inventory_purchase_order_items, orders_items, orders_orders, settings]
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Ash.NotLoaded
  alias Ash.Query

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    changeset =
      Changeset.before_transaction(changeset, fn changeset ->
        if Money.ExchangeRates.latest_rates_available?() do
          Changeset.add_error(
            changeset,
            "OPEN_EXCHANGE_RATES_APP_ID not set. Currency Conversion is not available",
            []
          )
        end
      end)

    if Money.ExchangeRates.latest_rates_available?() do
      AshOban.schedule_and_run_triggers(:craftplan, actor: context.actor)
    else
      Logger.warning("OPEN_EXCHANGE_RATES_APP_ID not set. Currency Conversion is not available")
    end

    changeset
  end
end
