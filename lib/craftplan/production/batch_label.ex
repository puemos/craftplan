defmodule Craftplan.Production.BatchLabel do
  @moduledoc false

  alias Craftplan.Inventory.Material
  alias Craftplan.Settings
  alias Decimal, as: D

  require Ash.Query

  def snapshot(product, components_map, actor) do
    settings = label_settings(actor)

    %{
      "product_name" => product.name,
      "sku" => product.sku,
      "ingredients" => ingredient_snapshot(components_map, actor),
      "allergens" => Enum.map(product.allergens || [], & &1.name),
      "nutrition_facts" => Enum.map(product.nutritional_facts || [], &nutrition_snapshot/1),
      "net_quantity" => decimal_string(product.nutrition_output_quantity),
      "net_quantity_unit" => product.nutrition_output_unit && to_string(product.nutrition_output_unit),
      "durability_type" => to_string(product.durability_type || :best_before),
      "shelf_life_days" => product.shelf_life_days,
      "storage_instructions" => product.storage_instructions,
      "country_of_origin" => product.country_of_origin,
      "food_business_name" => settings.food_business_name || settings.email_from_name,
      "food_business_address" => settings.food_business_address
    }
  end

  def data(batch, actor) do
    snapshot = batch.label_snapshot || %{}

    if map_size(snapshot) == 0 do
      snapshot(batch.product, batch.components_map || %{}, actor)
    else
      snapshot
    end
  end

  def ingredients(snapshot), do: value(snapshot, "ingredients", [])
  def allergens(snapshot), do: value(snapshot, "allergens", [])
  def nutrition_facts(snapshot), do: value(snapshot, "nutrition_facts", [])
  def product_name(snapshot), do: value(snapshot, "product_name", "")
  def sku(snapshot), do: value(snapshot, "sku", "")
  def net_quantity(snapshot), do: value(snapshot, "net_quantity")
  def net_quantity_unit(snapshot), do: value(snapshot, "net_quantity_unit")
  def shelf_life_days(snapshot), do: value(snapshot, "shelf_life_days")
  def durability_type(snapshot), do: value(snapshot, "durability_type", "best_before")
  def storage_instructions(snapshot), do: value(snapshot, "storage_instructions")
  def country_of_origin(snapshot), do: value(snapshot, "country_of_origin")
  def food_business_name(snapshot), do: value(snapshot, "food_business_name")
  def food_business_address(snapshot), do: value(snapshot, "food_business_address")

  @code39 %{
    "0" => "nnnwwnwnn",
    "1" => "wnnwnnnnw",
    "2" => "nnwwnnnnw",
    "3" => "wnwwnnnnn",
    "4" => "nnnwwnnnw",
    "5" => "wnnwwnnnn",
    "6" => "nnwwwnnnn",
    "7" => "nnnwnnwnw",
    "8" => "wnnwnnwnn",
    "9" => "nnwwnnwnn",
    "A" => "wnnnnwnnw",
    "B" => "nnwnnwnnw",
    "C" => "wnwnnwnnn",
    "D" => "nnnnwwnnw",
    "E" => "wnnnwwnnn",
    "F" => "nnwnwwnnn",
    "G" => "nnnnnwwnw",
    "H" => "wnnnnwwnn",
    "I" => "nnwnnwwnn",
    "J" => "nnnnwwwnn",
    "K" => "wnnnnnnww",
    "L" => "nnwnnnnww",
    "M" => "wnwnnnnwn",
    "N" => "nnnnwnnww",
    "O" => "wnnnwnnwn",
    "P" => "nnwnwnnwn",
    "Q" => "nnnnnnwww",
    "R" => "wnnnnnwwn",
    "S" => "nnwnnnwwn",
    "T" => "nnnnwnwwn",
    "U" => "wwnnnnnnw",
    "V" => "nwwnnnnnw",
    "W" => "wwwnnnnnn",
    "X" => "nwnnwnnnw",
    "Y" => "wwnnwnnnn",
    "Z" => "nwwnwnnnn",
    "-" => "nwnnnnwnw",
    "." => "wwnnnnwnn",
    " " => "nwwnnnwnn",
    "$" => "nwnwnwnnn",
    "/" => "nwnwnnnwn",
    "+" => "nwnnnwnwn",
    "%" => "nnnwnwnwn",
    "*" => "nwnnwnwnn"
  }

  def barcode(value) do
    encoded =
      value
      |> to_string()
      |> String.upcase()
      |> String.graphemes()
      |> Enum.map(fn character ->
        if Map.has_key?(@code39, character), do: character, else: "-"
      end)
      |> then(&(["*"] ++ &1 ++ ["*"]))

    {bars, width} =
      Enum.reduce(encoded, {[], 0}, fn character, {bars, offset} ->
        {character_bars, character_width} = code39_character(@code39[character], offset)
        {bars ++ character_bars, offset + character_width + 2}
      end)

    %{bars: bars, width: max(width - 2, 1)}
  end

  def value(map, key, default \\ nil), do: Map.get(map, key, default)

  def decimal_value(map, key) do
    case value(map, key) do
      nil -> nil
      %D{} = decimal -> decimal
      value -> D.new(to_string(value))
    end
  end

  defp ingredient_snapshot(components_map, actor) do
    quantities =
      Map.new(components_map, fn {id, qty} -> {to_string(id), D.new(to_string(qty))} end)

    ids = Map.keys(quantities)

    case ids do
      [] ->
        []

      ids ->
        Material
        |> Ash.Query.filter(id in ^ids)
        |> Ash.Query.load(allergens: [:name])
        |> Ash.read!(actor: actor)
        |> Enum.map(fn material ->
          %{
            "name" => material.name,
            "quantity" => quantities |> Map.fetch!(to_string(material.id)) |> D.to_string(),
            "allergens" => Enum.map(material.allergens || [], & &1.name)
          }
        end)
        |> Enum.sort(fn left, right ->
          D.gt?(D.new(left["quantity"]), D.new(right["quantity"]))
        end)
    end
  end

  defp nutrition_snapshot(fact) do
    %{
      "name" => fact.name,
      "amount" => D.to_string(fact.amount),
      "unit" => to_string(fact.unit),
      "parent_key" => fact.parent_key,
      "per_quantity" => fact.per_quantity && D.to_string(fact.per_quantity),
      "per_unit" => fact.per_unit && to_string(fact.per_unit),
      "declaration" => fact.declaration?
    }
  end

  defp label_settings(actor) do
    case Settings.get_settings(actor: actor) do
      {:ok, settings} -> settings
      _ -> %{food_business_name: nil, food_business_address: nil, email_from_name: "Craftplan"}
    end
  end

  defp decimal_string(nil), do: nil
  defp decimal_string(%D{} = value), do: D.to_string(value)
  defp decimal_string(value), do: to_string(value)

  defp code39_character(pattern, offset) do
    pattern
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce({[], offset}, fn {size, index}, {bars, x} ->
      width = if size == "w", do: 5, else: 2
      bars = if rem(index, 2) == 0, do: bars ++ [%{x: x, width: width}], else: bars
      {bars, x + width}
    end)
    |> then(fn {bars, final_x} -> {bars, final_x - offset} end)
  end
end
