defmodule Craftplan.Orders.Changes.AssignCurrencyOrder do
  @moduledoc """
  Run a currency conversion on all records and save to the db
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Orders.Order

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      actor = Keyword.get(opts, :actor)

      currency = Craftplan.Settings.get_settings!().currency

      shipping_total = Changeset.get_attribute(changeset, :shipping_total)

      shipping_total =
        if !is_nil(shipping_total) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(shipping_total, currency)
        end

      discount_total = Changeset.get_attribute(changeset, :discount_total)

      discount_total =
        if !is_nil(discount_total) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(discount_total, currency)
        end

      tax_total = Changeset.get_attribute(changeset, :tax_total)

      tax_total =
        if !is_nil(tax_total) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(tax_total, currency)
        end

      changeset
      |> Changeset.for_update(:update_currency,
        discount_total: discount_total,
        shipping_total: shipping_total,
        tax_total: tax_total
      )
      |> Ash.update(actor: actor, authorize?: false)
    end)
  end
end
