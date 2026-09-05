defmodule Craftplan.Orders.Changes.BatchComplete do
  @moduledoc false
  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Production.Batching
  alias Decimal, as: D

  @impl true
  def change(changeset, _opts, _ctx) do
    produced_qty = Changeset.get_argument(changeset, :produced_qty)
    duration_minutes = Changeset.get_argument(changeset, :duration_minutes)
    completed_map = Changeset.get_argument(changeset, :completed_map)
    lot_plan = Changeset.get_argument(changeset, :lot_plan)

    changeset
    |> Changeset.filter(expr(status == :in_progress))
    |> Changeset.force_change_attribute(:status, :completed)
    |> Changeset.force_change_attribute(:produced_qty, produced_qty)
    |> Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
    |> Changeset.before_action(fn changeset ->
      batch = changeset.data
      actor = changeset.context[:private][:actor]

      cond do
        batch.status != :in_progress ->
          Changeset.add_error(changeset, "Only an in-progress batch can be completed")

        Batching.batch_consumed?(batch, actor) ->
          case Batching.validate_recorded_consumption(batch, produced_qty, actor) do
            :ok -> changeset
            {:error, reason} -> lot_plan_error(changeset, reason)
          end

        true ->
          resolved_plan =
            if lot_plan && map_size(lot_plan) > 0 do
              {:ok, lot_plan}
            else
              Batching.auto_select_lots(batch, produced_qty)
            end

          case resolved_plan do
            {:ok, plan} when map_size(plan) == 0 ->
              changeset

            {:ok, plan} ->
              case Batching.consume_batch(batch, plan,
                     actor: actor,
                     expected_output_qty: produced_qty
                   ) do
                {:ok, _} -> changeset
                {:error, reason} -> lot_plan_error(changeset, reason)
              end

            {:error, reason} ->
              lot_plan_error(changeset, reason)
          end
      end
    end)
    |> Changeset.after_action(fn changeset, batch ->
      actor = changeset.context[:private][:actor]

      case Batching.complete_batch(batch,
             actor: actor,
             produced_qty: produced_qty,
             duration_minutes: duration_minutes,
             completed_map: completed_map
           ) do
        {:ok, _} -> {:ok, batch}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp lot_plan_error(changeset, {:insufficient_stock, material_id, required, short}) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Insufficient stock for material %{material_id}. Need %{required}, short by %{short}.",
      vars: %{
        material_id: material_id,
        required: D.to_string(required),
        short: D.to_string(short)
      }
    )
  end

  defp lot_plan_error(changeset, {:lot_plan_quantity_mismatch, material_id, required, planned}) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Lot quantities for material %{material_id} must total %{required}; received %{planned}.",
      vars: %{
        material_id: material_id,
        required: D.to_string(required),
        planned: D.to_string(planned)
      }
    )
  end

  defp lot_plan_error(changeset, {:insufficient_lot_stock, lot_id, requested, available}) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Lot %{lot_id} has %{available} available; %{requested} was requested.",
      vars: %{
        lot_id: lot_id,
        requested: D.to_string(requested),
        available: D.to_string(available)
      }
    )
  end

  defp lot_plan_error(changeset, {:lot_material_mismatch, lot_id, _material_id}) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Lot %{lot_id} does not belong to the selected material.",
      vars: %{lot_id: lot_id}
    )
  end

  defp lot_plan_error(changeset, {:lot_plan_materials_mismatch, _expected, _actual}) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Select the exact required quantity for every material in the frozen recipe."
    )
  end

  defp lot_plan_error(changeset, reason) do
    Changeset.add_error(changeset,
      field: :lot_plan,
      message: "Invalid lot plan: %{reason}",
      vars: %{reason: inspect(reason)}
    )
  end
end
