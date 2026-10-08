defmodule Craftplan.Inventory.Intermediates do
  @moduledoc "Native production of stocked materials, with frozen recipes and lot genealogy."
  alias Ash.Changeset
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialBatch
  alias Craftplan.Inventory.MaterialRecipe
  alias Decimal, as: D

  require Ash.Query

  def latest_recipe(material_id, actor) do
    MaterialRecipe
    |> Ash.Query.filter(material_id == ^material_id)
    |> Ash.Query.sort(version: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(actor: actor)
  end

  def recipes(material_id, actor) do
    MaterialRecipe
    |> Ash.Query.filter(material_id == ^material_id)
    |> Ash.Query.sort(version: :desc)
    |> Ash.read!(actor: actor)
  end

  def batches(material_id, actor) do
    MaterialBatch
    |> Ash.Query.filter(material_id == ^material_id)
    |> Ash.Query.sort(completed_at: :desc)
    |> Ash.Query.load(output_lot: [:current_stock], inputs: [lot: [:material]])
    |> Ash.read!(actor: actor)
  end

  def normalize_components(components, output_id, actor) do
    with {:ok, components} <- normalize_entries(components, "material_id"),
         true <- components != [],
         ids = Enum.map(components, & &1["material_id"]),
         true <- output_id not in ids and length(ids) == length(Enum.uniq(ids)),
         materials = Material |> Ash.Query.filter(id in ^ids) |> Ash.read!(actor: actor),
         true <- length(materials) == length(ids) do
      by_id = Map.new(materials, &{&1.id, &1})

      {:ok,
       Enum.map(components, fn c ->
         material = by_id[c["material_id"]]
         Map.merge(c, %{"name" => material.name, "unit" => to_string(material.unit)})
       end)}
    else
      _ ->
        {:error, "Add distinct input materials with positive quantities. The output cannot be its own input."}
    end
  end

  def validate_batch(changeset, actor) do
    material_id = Changeset.get_attribute(changeset, :material_id)
    recipe_id = Changeset.get_argument(changeset, :recipe_id)

    with {:ok, recipe} <- Ash.get(MaterialRecipe, recipe_id, actor: actor),
         true <- recipe != nil and recipe.material_id == material_id,
         {:ok, entries} <- normalize_entries(Changeset.get_argument(changeset, :inputs), "lot_id"),
         true <- entries != [],
         ids = Enum.map(entries, & &1["lot_id"]),
         true <- length(ids) == length(Enum.uniq(ids)),
         _materials =
           Material
           |> Ash.Query.filter(id in ^Enum.map(recipe.components, & &1["material_id"]))
           |> Ash.Query.sort(id: :asc)
           |> Ash.Query.lock(:for_update)
           |> Ash.read!(actor: actor),
         lots =
           Lot
           |> Ash.Query.filter(id in ^ids)
           |> Ash.Query.sort(id: :asc)
           |> Ash.Query.lock(:for_update)
           |> Ash.read!(actor: actor),
         lots = Ash.load!(lots, [:current_stock, material: [:current_stock]], actor: actor),
         true <- length(lots) == length(ids),
         {:ok, inputs} <- validate_inputs(lots, entries),
         true <-
           Enum.sort(Enum.uniq(Enum.map(lots, & &1.material_id))) ==
             Enum.sort(Enum.map(recipe.components, & &1["material_id"])) do
      {:ok, recipe, inputs}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, "Select valid input lots for every material in this recipe."}
    end
  end

  defp validate_inputs(lots, entries) do
    by_id = Map.new(entries, &{&1["lot_id"], D.new(&1["quantity"])})

    totals =
      Enum.reduce(lots, %{}, fn lot, acc ->
        Map.update(acc, lot.material_id, by_id[lot.id], &D.add(&1, by_id[lot.id]))
      end)

    Enum.reduce_while(lots, {:ok, []}, fn lot, {:ok, acc} ->
      quantity = by_id[lot.id]

      cond do
        lot.status != :available ->
          {:halt, {:error, "#{lot.lot_code} is not available for production."}}

        lot.expiry_date && Date.before?(lot.expiry_date, Date.utc_today()) ->
          {:halt, {:error, "#{lot.lot_code} has expired."}}

        D.gt?(quantity, lot.current_stock || D.new(0)) or
            D.gt?(totals[lot.material_id], lot.material.current_stock || D.new(0)) ->
          {:halt,
           {:error, "Insufficient stock in #{lot.lot_code}. Reduce the actual input quantity or choose another lot."}}

        true ->
          {:cont,
           {:ok,
            [
              %{lot: lot, quantity: quantity, unit_cost: lot.unit_cost || lot.material.price}
              | acc
            ]}}
      end
    end)
  end

  defp normalize_entries(entries, id_key) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      id = Map.get(entry, id_key) || Map.get(entry, String.to_existing_atom(id_key))
      quantity = Map.get(entry, "quantity") || Map.get(entry, :quantity)

      with {:ok, id} when is_binary(id) <- Ash.Type.cast_input(:uuid, id),
           {:ok, %D{} = quantity} <- Ash.Type.cast_input(:decimal, quantity),
           true <- D.gt?(quantity, D.new(0)) do
        {:cont, {:ok, acc ++ [%{id_key => id, "quantity" => D.to_string(quantity, :normal)}]}}
      else
        _ -> {:halt, {:error, "Every input needs a valid selection and positive quantity."}}
      end
    end)
  end

  defp normalize_entries(_, _), do: {:error, "Select the input materials and quantities."}
end
