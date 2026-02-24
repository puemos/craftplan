defmodule Craftplan.Orders.Changes.AssignCurrencyItem do
  @moduledoc """
  Run a currency conversion on all records and save to the db
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Orders.OrderItem

  require Ash.Query

  @impl true
  def change(changeset, opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      actor = Keyword.get(opts, :actor)

      currency = Craftplan.Settings.get_settings!().currency

      unit_price = Changeset.get_attribute(changeset, :unit_price)
      unit_cost = Changeset.get_attribute(changeset, :unit_cost)
      material_cost = Changeset.get_attribute(changeset, :material_cost)
      overhead_cost = Changeset.get_attribute(changeset, :overhead_cost)
      labor_cost = Changeset.get_attribute(changeset, :labor_cost)

      unit_cost =
        if !is_nil(unit_cost) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(unit_cost, currency)
        end

      labor_cost =
        if !is_nil(labor_cost) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(labor_cost, currency)
        end

      material_cost =
        if !is_nil(material_cost) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(material_cost, currency)
        end

      overhead_cost =
        if !is_nil(overhead_cost) && Money.ExchangeRates.latest_rates_available?() do
          Money.to_currency!(overhead_cost, currency)
        end

      changeset
      |> Changeset.for_update(:update,
        labor_cost: labor_cost,
        material_cost: material_cost,
        overhead_cost: overhead_cost,
        unit_cost: unit_cost
      )
      |> Ash.update(actor: actor, authorize?: false)
    end)
  end
end
