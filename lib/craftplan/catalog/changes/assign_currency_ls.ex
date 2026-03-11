defmodule Craftplan.Catalog.Changes.AssignCurrencyLS do
  @moduledoc """
  Run a currency conversion on all records and save to the db
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Catalog.LaborStep

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      currency = Craftplan.Settings.get_settings!().currency
      actor = Keyword.get(opts, :actor)
      rate_override = Changeset.get_attribute(changeset, :rate_override)

      rate_override =
        if !is_nil(rate_override) && Money.ExchangeRates.latest_rates_available?() do
          {currency, rate_override}
        end

      changeset
      |> Changeset.for_update(:update, rate_override: rate_override)
      |> Ash.update(actor: actor, authorize?: false)
    end)
  end
end
