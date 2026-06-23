defmodule Craftplan.Inventory.Changes.ValidateMaterialNutrition do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Inventory.NutritionalFact

  @impl true
  def change(changeset, _opts, _context) do
    entries =
      changeset
      |> Changeset.get_argument(:material_nutritional_facts)
      |> normalize_entries()

    facts_by_id = facts_by_id(entries)

    changeset
    |> validate_entry_amounts(entries)
    |> validate_child_not_greater(entries, facts_by_id, "saturates", "fat")
    |> validate_child_not_greater(entries, facts_by_id, "sugars", "carbohydrate")
  end

  defp normalize_entries(nil), do: []

  defp normalize_entries(entries) when is_map(entries) do
    entries
    |> Map.values()
    |> normalize_entries()
  end

  defp normalize_entries(entries) when is_list(entries), do: entries
  defp normalize_entries(_entries), do: []

  defp facts_by_id(entries) do
    ids =
      entries
      |> Enum.map(&field(&1, :nutritional_fact_id))
      |> Enum.filter(&present?/1)
      |> Enum.uniq()

    case ids do
      [] ->
        %{}

      _ ->
        NutritionalFact
        |> Query.filter(id in ^ids)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{&1.id, &1})
    end
  rescue
    _ -> %{}
  end

  defp validate_entry_amounts(changeset, entries) do
    Enum.reduce(entries, changeset, fn entry, changeset ->
      changeset
      |> validate_non_negative(entry, :amount)
      |> validate_positive(entry, :basis_quantity)
    end)
  end

  defp validate_non_negative(changeset, entry, field_name) do
    case decimal(field(entry, field_name)) do
      nil ->
        changeset

      value ->
        if Decimal.compare(value, Decimal.new(0)) == :lt do
          Changeset.add_error(changeset,
            field: :material_nutritional_facts,
            message: "#{field_name} must be greater than or equal to zero"
          )
        else
          changeset
        end
    end
  end

  defp validate_positive(changeset, entry, field_name) do
    case decimal(field(entry, field_name)) do
      nil ->
        changeset

      value ->
        if Decimal.compare(value, Decimal.new(0)) == :gt do
          changeset
        else
          Changeset.add_error(changeset,
            field: :material_nutritional_facts,
            message: "#{field_name} must be greater than zero"
          )
        end
    end
  end

  defp validate_child_not_greater(changeset, entries, facts_by_id, child_key, parent_key) do
    entries_by_key =
      entries
      |> Enum.group_by(fn entry -> fact_key(entry, facts_by_id) end)
      |> Map.new(fn {key, grouped} -> {key, List.first(grouped)} end)

    child = Map.get(entries_by_key, child_key)
    parent = Map.get(entries_by_key, parent_key)

    with true <- not is_nil(child),
         true <- not is_nil(parent),
         child_amount when not is_nil(child_amount) <- decimal(field(child, :amount)),
         parent_amount when not is_nil(parent_amount) <- decimal(field(parent, :amount)),
         :gt <- Decimal.compare(child_amount, parent_amount) do
      Changeset.add_error(changeset,
        field: :material_nutritional_facts,
        message: "#{child_key} cannot exceed #{parent_key}"
      )
    else
      _ -> changeset
    end
  end

  defp fact_key(entry, facts_by_id) do
    fact =
      entry
      |> field(:nutritional_fact_id)
      |> then(fn id -> Map.get(facts_by_id, id) end)

    case fact do
      %{key: key} -> key
      _ -> nil
    end
  end

  defp field(entry, name) when is_map(entry) do
    Map.get(entry, name) || Map.get(entry, Atom.to_string(name))
  end

  defp field(_entry, _name), do: nil

  defp decimal(nil), do: nil
  defp decimal(""), do: nil

  defp decimal(%Decimal{} = value), do: value

  defp decimal(value) do
    Decimal.new(to_string(value))
  rescue
    _ -> nil
  end

  defp present?(value), do: not is_nil(value) and String.trim(to_string(value)) != ""
end
