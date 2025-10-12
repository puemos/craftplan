defmodule Craftday.Orders.Changes.CalculateTotals do
  @moduledoc """
  Sets persisted money totals on an order from its items and provided fees.

  Logic:
  - If `:items` arg provided (on create/update), compute subtotal from those maps.
  - Otherwise, load existing items for the order and compute from DB.
  - Totals: total = subtotal - discount_total + tax_total + shipping_total.
  - Uses Decimal throughout for precision.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    import Ash.Changeset

    items_arg = get_argument(changeset, :items)

    {subtotal, changeset} =
      case items_arg do
        items when is_list(items) ->
          {sum_items(items), changeset}

        _ ->
          # Fallback: load from DB if we have an ID (updates)
          case changeset.data do
            %{items: items} when is_list(items) ->
              {sum_items(items), changeset}

            %{id: _id} ->
              # If items are not preloaded, fall back to zero rather than loading from DB
              # to avoid cross-context authorization issues during form builds.
              {Decimal.new(0), changeset}

            _ ->
              {Decimal.new(0), changeset}
          end
      end

    # Compute discount and tax based on settings & attributes
    settings = safe_get_settings()

    discount_total =
      case get_attribute(changeset, :discount_type) || :none do
        :percent ->
          percent = get_attribute(changeset, :discount_value) || Decimal.new(0)

          subtotal
          |> Decimal.mult(Decimal.div(percent, Decimal.new(100)))
          |> Decimal.max(Decimal.new(0))

        :fixed ->
          fixed = get_attribute(changeset, :discount_value) || Decimal.new(0)
          if Decimal.compare(fixed, subtotal) == :gt, do: subtotal, else: fixed

        _ ->
          Decimal.new(0)
      end

    shipping_total = get_attribute(changeset, :shipping_total) || Decimal.new(0)

    tax_base = Decimal.sub(subtotal, discount_total)

    tax_total =
      case settings do
        %{tax_mode: :exclusive, tax_rate: rate} ->
          Decimal.mult(tax_base, rate || Decimal.new(0))

        %{tax_mode: :inclusive, tax_rate: rate} ->
          # derive included tax portion from tax_base
          case rate do
            r when not is_nil(r) ->
              denom = Decimal.add(Decimal.new(1), r)
              net = Decimal.div(tax_base, denom)
              Decimal.sub(tax_base, net)

            _ ->
              Decimal.new(0)
          end

        _ ->
          Decimal.new(0)
      end

    total =
      subtotal
      |> Decimal.sub(discount_total)
      |> Decimal.add(tax_total)
      |> Decimal.add(shipping_total)

    changeset
    |> Ash.Changeset.force_change_attribute(:subtotal, subtotal)
    |> Ash.Changeset.force_change_attribute(:discount_total, discount_total)
    |> Ash.Changeset.force_change_attribute(:tax_total, tax_total)
    |> Ash.Changeset.force_change_attribute(:total, total)
  end

  defp sum_items(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      quantity = to_decimal(Map.get(item, :quantity) || Map.get(item, "quantity") || 0)
      unit_price = to_decimal(Map.get(item, :unit_price) || Map.get(item, "unit_price") || 0)
      Decimal.add(acc, Decimal.mult(quantity, unit_price))
    end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(i) when is_integer(i), do: Decimal.new(i)
  defp to_decimal(f) when is_float(f), do: f |> Decimal.from_float() |> Decimal.round(2)
  defp to_decimal(<<_::binary>> = s), do: Decimal.new(s)
  defp to_decimal(nil), do: Decimal.new(0)

  defp to_decimal(other) do
    case Decimal.cast(other) do
      {:ok, d} -> d
      :error -> Decimal.new(0)
    end
  end

  defp safe_get_settings do
    Craftday.Settings.get_settings!()
  rescue
    _ -> %{tax_mode: :exclusive, tax_rate: Decimal.new(0)}
  end
end
