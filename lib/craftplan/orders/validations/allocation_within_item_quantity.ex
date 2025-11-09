defmodule Craftplan.Orders.Validations.AllocationWithinItemQuantity do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias Decimal, as: D

  @impl true
  def validate(changeset, _opts, _ctx) do
    actor = Map.get(changeset.context, :actor)

    item_id = get_field(changeset, :order_item_id)
    planned_qty = Changeset.get_attribute(changeset, :planned_qty) || D.new(0)

    if is_nil(item_id) do
      :ok
    else
      case Orders.get_order_item_by_id(%{id: item_id}, actor: actor, authorize?: false) do
        {:ok, item} ->
          # Sum planned quantities across other allocations for this item
          existing_sum =
            OrderItemBatchAllocation
            |> Ash.Query.new()
            |> Ash.Query.filter(order_item_id == ^item_id)
            |> Ash.Query.select([:id, :planned_qty])
            |> Ash.read!(actor: actor, authorize?: false)
            |> Enum.reject(&(&1.id == Changeset.get_data(changeset, :id)))
            |> Enum.reduce(D.new(0), fn a, acc -> D.add(acc, a.planned_qty || D.new(0)) end)

          total = D.add(existing_sum, planned_qty)

          if D.compare(total, item.quantity || D.new(0)) == :gt do
            {:error, message: "total allocated planned quantity exceeds order item quantity"}
          else
            :ok
          end

        _ ->
          :ok
      end
    end
  end

  defp get_field(changeset, name) do
    Changeset.get_attribute(changeset, name) || Changeset.get_data(changeset, name)
  end
end
