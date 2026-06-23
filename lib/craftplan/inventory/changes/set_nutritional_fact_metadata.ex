defmodule Craftplan.Inventory.Changes.SetNutritionalFactMetadata do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Inventory.Nutrition

  @impl true
  def change(changeset, _opts, _context) do
    key = present_value(changeset, :key)
    name = present_value(changeset, :name)

    key =
      cond do
        present?(key) ->
          key

        present?(name) ->
          Nutrition.standard_key_for_name(name) || Nutrition.custom_key(name)

        true ->
          key
      end

    changeset =
      if present?(key) do
        Changeset.force_change_attribute(changeset, :key, key)
      else
        changeset
      end

    case Nutrition.standard_fact(key) do
      nil ->
        changeset
        |> maybe_set(:eu_required, false)
        |> maybe_set(:system, false)

      fact ->
        changeset
        |> Changeset.force_change_attribute(:name, fact.name)
        |> Changeset.force_change_attribute(:default_unit, fact.default_unit)
        |> Changeset.force_change_attribute(:parent_key, fact.parent_key)
        |> Changeset.force_change_attribute(:sort_order, fact.sort_order)
        |> Changeset.force_change_attribute(:eu_required, fact.eu_required)
        |> Changeset.force_change_attribute(:system, fact.system)
    end
  end

  defp present_value(changeset, field) do
    Changeset.get_attribute(changeset, field) || Map.get(changeset.data, field)
  end

  defp maybe_set(changeset, field, value) do
    case present_value(changeset, field) do
      nil -> Changeset.force_change_attribute(changeset, field, value)
      _ -> changeset
    end
  end

  defp present?(value), do: not is_nil(value) and String.trim(to_string(value)) != ""
end
