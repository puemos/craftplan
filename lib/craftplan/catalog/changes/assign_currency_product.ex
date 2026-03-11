defmodule Craftplan.Catalog.Changes.AssignCurrencyProduct do
  @moduledoc """
  Run a currency conversion on all records and save to the db
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Catalog.Product

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      actor = Keyword.get(opts, :actor)

      currency = Craftplan.Settings.get_settings!().currency

      price = Changeset.get_attribute(changeset, :price)

      price =
        if !is_nil(price) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(price, currency)
        end

      changeset
      |> Changeset.for_update(:update, price: price)
      |> Ash.update(actor: actor, authorize?: false)
    end)
  end
end
