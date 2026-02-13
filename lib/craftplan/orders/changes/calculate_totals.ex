defmodule Craftplan.Orders.Changes.CalculateTotals do
  @moduledoc """
  Sets persisted money totals on an order from its items and provided fees.

  Logic:
  - If `:items` arg provided (on create/update), compute subtotal from those maps.
  - Otherwise, load existing items for the order and compute from DB.
  - Totals: total = subtotal - discount_total + tax_total + shipping_total.
  - Uses Decimal throughout for precision.
  """

  use Ash.Resource.Change

  alias Craftplan.DecimalHelpers

  @impl true
  def change(changeset, _opts, _context) do
    import Ash.Changeset

    currency = Craftplan.Settings.get_settings!().currency
    items_arg = get_argument(changeset, :items)

    {subtotal, changeset} =
      case items_arg do
        items when is_list(items) ->
          {sum_items(items, currency), changeset}

        _ ->
          # Fallback: load from DB if we have an ID (updates)
          case changeset.data do
            %{items: items} when is_list(items) ->
              {sum_items(items, currency), changeset}

            %{id: _id} ->
              # If items are not preloaded, fall back to zero rather than loading from DB
              # to avoid cross-context authorization issues during form builds.
              {Money.new!(0, currency), changeset}

            _ ->
              {Money.new!(0, currency), changeset}
          end
      end

    # Compute discount and tax based on settings & attributes
    settings = safe_get_settings()

    discount_total =
      case get_attribute(changeset, :discount_type) || :none do
        :percent ->
          percent = get_attribute(changeset, :discount_value) || Decimal.new(0)

          subtotal
          |> Money.mult!(Decimal.div(percent, Decimal.new(100)))
          |> Money.max!(Money.new!(0, currency))

        :fixed ->
          fixed = get_attribute(changeset, :discount_value) || Decimal.new(0)
          if Money.compare!(fixed, subtotal) == :gt, do: subtotal, else: fixed

        _ ->
          Money.new!(0, currency)
      end

    shipping_total = get_attribute(changeset, :shipping_total) || Money.new!(0, currency)

    tax_base = Money.sub!(subtotal, discount_total)

    tax_total =
      case settings do
        %{tax_mode: :exclusive, tax_rate: rate} ->
          Money.mult!(tax_base, rate || Money.new!(0, currency))

        %{tax_mode: :inclusive, tax_rate: rate} ->
          # derive included tax portion from tax_base
          case rate do
            r when not is_nil(r) ->
              denom = Money.mult!(Money.new!(1, currency), r)
              net = Money.div!(tax_base, denom)
              Money.sub!(tax_base, net)

            _ ->
              Money.new!(0, currency)
          end

        _ ->
          Money.new!(0, currency)
      end

    total =
      subtotal
      |> Money.sub!(discount_total)
      |> Money.add!(tax_total)
      |> Money.add!(shipping_total)

    changeset
    |> Ash.Changeset.force_change_attribute(:subtotal, subtotal)
    |> Ash.Changeset.force_change_attribute(:discount_total, discount_total)
    |> Ash.Changeset.force_change_attribute(:tax_total, tax_total)
    |> Ash.Changeset.force_change_attribute(:total, total)
  end

  defp sum_items(items, currency) do
    Enum.reduce(items, Money.new!(0, currency), fn item, acc ->
      quantity =
        DecimalHelpers.to_decimal(Map.get(item, :quantity) || Map.get(item, "quantity") || 0)

      unit_price =
        Map.get(item, :unit_price) || Money.new!(0, currency)

      Money.add!(acc, Money.mult!(unit_price, quantity))
    end)
  end

  defp safe_get_settings do
    Craftplan.Settings.get_settings!()
  rescue
    _ -> %{tax_mode: :exclusive, tax_rate: Decimal.new(0)}
  end
end
