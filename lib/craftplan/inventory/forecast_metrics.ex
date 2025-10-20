defmodule Craftplan.Inventory.ForecastMetrics do
  @moduledoc """
  Pure functions for computing inventory forecast metrics such as average usage,
  reorder points, and suggested purchase quantities.
  """

  alias Decimal, as: D

  @type decimal ::
          D.t()
          | number()

  @default_actual_weight 0.6
  @default_planned_weight 0.4

  @doc """
  Calculates the blended average daily use.

  ## Parameters

    * `actual_samples` - enumerable of historical actual usage values.
    * `planned_samples` - enumerable of forthcoming planned usage values.
    * `opts` - `:actual_weight` and `:planned_weight` overrides (defaults 0.6 / 0.4).
  """
  @spec avg_daily_use(Enum.t(), Enum.t(), keyword()) :: D.t()
  def avg_daily_use(actual_samples, planned_samples, opts \\ []) do
    actual_weight = Keyword.get(opts, :actual_weight, @default_actual_weight)
    planned_weight = Keyword.get(opts, :planned_weight, @default_planned_weight)

    actual_avg = mean(actual_samples)
    planned_avg = mean(planned_samples)

    cond do
      is_nil(actual_avg) and is_nil(planned_avg) ->
        D.new(0)

      is_nil(planned_avg) ->
        actual_avg

      is_nil(actual_avg) ->
        planned_avg

      true ->
        actual_component = D.mult(actual_avg, D.from_float(actual_weight))
        planned_component = D.mult(planned_avg, D.from_float(planned_weight))
        D.add(actual_component, planned_component)
    end
  end

  @doc """
  Calculates demand variability (standard deviation of blended daily use).
  Falls back to half the blended average when there are fewer than 10 samples.
  """
  @spec demand_variability(Enum.t(), Enum.t(), keyword()) :: D.t()
  def demand_variability(actual_samples, planned_samples, opts \\ []) do
    minimum_samples = Keyword.get(opts, :minimum_samples, 10)
    samples = normalize_samples(actual_samples) ++ normalize_samples(planned_samples)

    cond do
      samples == [] ->
        D.new(0)

      length(samples) < minimum_samples ->
        avg =
          actual_samples
          |> avg_daily_use(planned_samples, opts)
          |> D.mult(D.new("0.5"))

        max_decimal(avg, D.new(0))

      true ->
        mean =
          samples
          |> Enum.sum()
          |> Kernel./(length(samples))

        variance =
          Enum.reduce(samples, 0.0, fn sample, acc ->
            diff = sample - mean
            acc + diff * diff
          end) / length(samples)

        variance
        |> :math.sqrt()
        |> D.from_float()
    end
  end

  @doc """
  Computes the expected demand that will occur during the lead time window.
  """
  @spec lead_time_demand(D.t(), integer() | float() | D.t()) :: D.t()
  def lead_time_demand(avg_daily_use, lead_time_days) do
    lt = decimal_from_number(lead_time_days)
    max_decimal(D.mult(avg_daily_use, lt), D.new(0))
  end

  @doc """
  Calculates safety stock using the standard deviation and lead time.
  """
  @spec safety_stock(D.t(), D.t(), integer() | float() | D.t()) :: D.t()
  def safety_stock(z_factor, variability, lead_time_days) do
    cond do
      compare(z_factor, 0) != :gt ->
        D.new(0)

      compare(variability, 0) != :gt ->
        D.new(0)

      compare(lead_time_days, 0) != :gt ->
        D.new(0)

      true ->
        lt_root =
          lead_time_days
          |> decimal_from_number()
          |> D.to_float()
          |> max(0.0)
          |> :math.sqrt()
          |> D.from_float()

        z_factor
        |> D.mult(variability)
        |> D.mult(lt_root)
    end
  end

  @doc """
  Calculates the reorder point (lead time demand + safety stock).
  """
  @spec reorder_point(D.t(), D.t()) :: D.t()
  def reorder_point(lead_time_demand, safety_stock) do
    D.add(lead_time_demand, safety_stock)
  end

  @doc """
  Determines cover days. Returns `nil` when average usage is zero to indicate
  open-ended cover.
  """
  @spec cover_days(decimal(), decimal()) :: D.t() | nil
  def cover_days(on_hand, avg_daily_use) do
    on_hand = decimal_from_number(on_hand)
    avg_daily_use = decimal_from_number(avg_daily_use)

    if compare(avg_daily_use, 0) == :gt do
      D.div(on_hand, avg_daily_use)
    end
  end

  @doc """
  Returns the first date where projected balance drops below zero.

  `projected_balances` should be an enumerable of `{Date.t(), decimal}`.
  """
  @spec stockout_date([{Date.t(), decimal()}]) :: Date.t() | nil
  def stockout_date(projected_balances) do
    Enum.find_value(projected_balances, fn {date, balance} ->
      balance = decimal_from_number(balance)

      if compare(balance, 0) == :lt do
        date
      end
    end)
  end

  @doc """
  Calculates the order-by date by subtracting lead time days from the stockout date.
  Returns `nil` when stockout date is absent.
  """
  @spec order_by_date(Date.t() | nil, integer() | float() | D.t()) :: Date.t() | nil
  def order_by_date(nil, _lead_time_days), do: nil

  def order_by_date(stockout_date, lead_time_days) do
    days =
      lead_time_days
      |> decimal_from_number()
      |> D.to_float()
      |> Float.ceil()
      |> trunc()
      |> max(0)

    Date.add(stockout_date, -days)
  end

  @doc """
  Computes the suggested purchase quantity.

  Options:
    * `:pack_size` (default 1)
    * `:avg_daily_use` (required when `:max_cover_days` is provided)
    * `:max_cover_days` - cap suggested quantity to maintain this cover
  """
  @spec suggested_po_qty(D.t(), decimal(), decimal(), keyword()) :: D.t()
  def suggested_po_qty(reorder_point, on_hand, on_order, opts \\ []) do
    pack_size = decimal_from_number(Keyword.get(opts, :pack_size, 1))
    avg_daily_use = Keyword.get(opts, :avg_daily_use)
    max_cover_days = Keyword.get(opts, :max_cover_days)

    on_hand = decimal_from_number(on_hand)
    on_order = decimal_from_number(on_order)

    base_needed =
      reorder_point
      |> D.sub(D.add(on_hand, on_order))
      |> max_decimal(D.new(0))

    capped_needed =
      case {max_cover_days, avg_daily_use} do
        {nil, _} ->
          base_needed

        {_, nil} ->
          base_needed

        {cover_days, _avg} when cover_days <= 0 ->
          base_needed

        {cover_days, avg} ->
          target_stock =
            avg
            |> decimal_from_number()
            |> D.mult(decimal_from_number(cover_days))

          current_stock = D.add(on_hand, on_order)

          max_additional =
            target_stock
            |> D.sub(current_stock)
            |> max_decimal(D.new(0))

          min_decimal(base_needed, max_additional)
      end

    ceil_to_pack_size(capped_needed, pack_size)
  end

  @doc """
  Derives the risk state given projected balances.
  Returns one of `:shortage`, `:watch`, or `:balanced`.
  """
  @spec risk_state([{Date.t(), decimal()}]) :: :shortage | :watch | :balanced
  def risk_state(projected_balances) do
    balances =
      Enum.map(projected_balances, fn {_date, balance} ->
        decimal_from_number(balance)
      end)

    cond do
      Enum.any?(balances, &(compare(&1, 0) == :lt)) ->
        :shortage

      Enum.any?(balances, &(compare(&1, 0) == :eq)) ->
        :watch

      true ->
        :balanced
    end
  end

  defp ceil_to_pack_size(quantity, pack_size) do
    cond do
      compare(quantity, 0) != :gt ->
        D.new(0)

      compare(pack_size, 0) != :gt ->
        quantity

      true ->
        quantity
        |> D.div(pack_size)
        |> D.round(0, :ceiling)
        |> D.mult(pack_size)
    end
  end

  defp mean(samples) do
    values = normalize_samples(samples)

    case values do
      [] ->
        nil

      _ ->
        D.from_float(Enum.sum(values) / length(values))
    end
  end

  defp normalize_samples(samples) do
    samples
    |> Enum.map(&extract_sample_value/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn
      %D{} = decimal -> D.to_float(decimal)
      value when is_number(value) -> value * 1.0
    end)
  end

  defp extract_sample_value({_, value}), do: value
  defp extract_sample_value(%{quantity: value}), do: value
  defp extract_sample_value(%{value: value}), do: value
  defp extract_sample_value(value) when is_number(value) or is_struct(value, D), do: value
  defp extract_sample_value(_), do: nil

  defp decimal_from_number(%D{} = decimal), do: decimal
  defp decimal_from_number(value) when is_integer(value), do: D.new(value)
  defp decimal_from_number(value) when is_float(value), do: D.from_float(value)
  defp decimal_from_number(value) when is_binary(value), do: D.new(value)
  defp decimal_from_number(nil), do: D.new(0)

  defp max_decimal(left, right) do
    case compare(left, right) do
      :lt -> right
      _ -> left
    end
  end

  defp min_decimal(left, right) do
    case compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  defp compare(left, right) do
    D.compare(decimal_from_number(left), decimal_from_number(right))
  end
end
