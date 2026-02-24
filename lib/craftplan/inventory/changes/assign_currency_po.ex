defmodule Craftplan.Inventory.Changes.AssignCurrencyPO do
  @moduledoc """
  Run a currency conversion on all records and save to the db
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Inventory.PurchaseOrderItem

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      actor = Keyword.get(opts, :actor)

      currency = Craftplan.Settings.get_settings!().currency

      unit_price = Changeset.get_attribute(changeset, :unit_price)

      unit_price =
        if !is_nil(unit_price) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(unit_price, currency)
        end

      changeset
      |> Changeset.for_update(:update, unit_price: unit_price)
      |> Ash.update(actor: actor, authorize?: false)
    end)
  end
end
