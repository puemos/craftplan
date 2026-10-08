defmodule Craftplan.Inventory.Changes.ProduceMaterialBatch do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Inventory.Intermediates
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.MaterialBatchInput
  alias Craftplan.Inventory.Movement
  alias Decimal, as: D

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Changeset.before_action(fn changeset ->
      actor = changeset.context[:private][:actor]

      with {:ok, recipe, inputs} <- Intermediates.validate_batch(changeset, actor),
           total_cost =
             Enum.reduce(inputs, D.new(0), fn input, acc ->
               D.add(acc, D.mult(input.quantity, input.unit_cost))
             end),
           {:ok, lot} <-
             Lot
             |> Changeset.for_create(:create, %{
               material_id: Changeset.get_attribute(changeset, :material_id),
               lot_code: Changeset.get_attribute(changeset, :lot_code),
               received_quantity: Changeset.get_attribute(changeset, :actual_quantity),
               expiry_date: Changeset.get_attribute(changeset, :expiry_date),
               received_at: DateTime.utc_now(),
               unit_cost: D.div(total_cost, Changeset.get_attribute(changeset, :actual_quantity))
             })
             |> Ash.create(actor: actor) do
        changeset
        |> Changeset.force_change_attribute(:output_lot_id, lot.id)
        |> Changeset.force_change_attribute(:recipe_snapshot, %{
          "version" => recipe.version,
          "yield_quantity" => D.to_string(recipe.yield_quantity, :normal),
          "components" => recipe.components
        })
        |> Changeset.force_change_attribute(:total_cost, total_cost)
        |> Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
        |> Changeset.set_context(%{production_inputs: inputs})
      else
        {:error, reason} when is_binary(reason) ->
          Changeset.add_error(changeset, field: :inputs, message: reason)

        {:error, reason} ->
          Changeset.add_error(changeset, reason)
      end
    end)
    |> Changeset.after_action(fn changeset, batch ->
      actor = changeset.context[:private][:actor]
      inputs = changeset.context.production_inputs

      result =
        Enum.reduce_while(inputs, :ok, fn input, :ok ->
          with {:ok, _} <-
                 MaterialBatchInput
                 |> Changeset.for_create(:create, %{
                   material_batch_id: batch.id,
                   lot_id: input.lot.id,
                   quantity: input.quantity,
                   unit_cost: input.unit_cost
                 })
                 |> Ash.create(actor: actor),
               {:ok, _} <-
                 Movement
                 |> Changeset.for_create(:adjust_stock, %{
                   material_id: input.lot.material_id,
                   lot_id: input.lot.id,
                   quantity: D.negate(input.quantity),
                   reason: "Made #{batch.lot_code}"
                 })
                 |> Ash.create(actor: actor) do
            {:cont, :ok}
          else
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      with :ok <- result,
           {:ok, _} <-
             Movement
             |> Changeset.for_create(:adjust_stock, %{
               material_id: batch.material_id,
               lot_id: batch.output_lot_id,
               quantity: batch.actual_quantity,
               reason: "Produced #{batch.lot_code}"
             })
             |> Ash.create(actor: actor) do
        {:ok, batch}
      end
    end)
  end
end
