defmodule Craftplan.Inventory.Nutrition do
  @moduledoc false

  @standard_facts [
    %{
      key: "energy_kj",
      name: "Energy (kJ)",
      default_unit: :kilojoule,
      parent_key: nil,
      sort_order: 10,
      eu_required: true,
      system: true
    },
    %{
      key: "energy_kcal",
      name: "Energy (kcal)",
      default_unit: :kcal,
      parent_key: nil,
      sort_order: 20,
      eu_required: true,
      system: true
    },
    %{
      key: "fat",
      name: "Fat",
      default_unit: :gram,
      parent_key: nil,
      sort_order: 30,
      eu_required: true,
      system: true
    },
    %{
      key: "saturates",
      name: "Saturates",
      default_unit: :gram,
      parent_key: "fat",
      sort_order: 40,
      eu_required: true,
      system: true
    },
    %{
      key: "carbohydrate",
      name: "Carbohydrate",
      default_unit: :gram,
      parent_key: nil,
      sort_order: 50,
      eu_required: true,
      system: true
    },
    %{
      key: "sugars",
      name: "Sugars",
      default_unit: :gram,
      parent_key: "carbohydrate",
      sort_order: 60,
      eu_required: true,
      system: true
    },
    %{
      key: "protein",
      name: "Protein",
      default_unit: :gram,
      parent_key: nil,
      sort_order: 70,
      eu_required: true,
      system: true
    },
    %{
      key: "salt",
      name: "Salt",
      default_unit: :gram,
      parent_key: nil,
      sort_order: 80,
      eu_required: true,
      system: true
    }
  ]

  @facts_by_key Map.new(@standard_facts, &{&1.key, &1})

  @legacy_names %{
    "energy (kj)" => "energy_kj",
    "energy kj" => "energy_kj",
    "kilojoules" => "energy_kj",
    "kj" => "energy_kj",
    "energy" => "energy_kcal",
    "energy (kcal)" => "energy_kcal",
    "energy kcal" => "energy_kcal",
    "calories" => "energy_kcal",
    "kcal" => "energy_kcal",
    "fat" => "fat",
    "saturated fat" => "saturates",
    "saturates" => "saturates",
    "carbohydrate" => "carbohydrate",
    "carbohydrates" => "carbohydrate",
    "sugar" => "sugars",
    "sugars" => "sugars",
    "protein" => "protein",
    "salt" => "salt"
  }

  def standard_facts, do: @standard_facts

  def standard_keys, do: Map.keys(@facts_by_key)

  def standard_fact(key) when is_binary(key), do: Map.get(@facts_by_key, key)
  def standard_fact(_key), do: nil

  def standard_key_for_name(name) when is_binary(name) do
    @legacy_names[normalize_name(name)]
  end

  def standard_key_for_name(_name), do: nil

  def custom_key(name) do
    normalized =
      name
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]+/u, "_")
      |> String.trim("_")

    case normalized do
      "" -> "custom:fact"
      value -> "custom:" <> value
    end
  end

  def declaration_output?(quantity, unit) do
    quantity = decimal(quantity)

    not is_nil(quantity) and Decimal.compare(quantity, Decimal.new(0)) == :gt and
      unit in [:gram, :milliliter]
  end

  defp normalize_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end

  defp decimal(nil), do: nil
  defp decimal(%Decimal{} = value), do: value
  defp decimal(value), do: Decimal.new(to_string(value))
end
