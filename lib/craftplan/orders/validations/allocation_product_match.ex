defmodule Craftplan.Orders.Validations.AllocationProductMatch do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Craftplan.Orders

  @impl true
  def validate(changeset, _opts, _ctx) do
    actor = Map.get(changeset.context, :actor)

    batch_id = field(changeset, :production_batch_id)
    item_id = field(changeset, :order_item_id)

    if is_nil(batch_id) or is_nil(item_id) do
      :ok
    else
      case {
        Orders.get_production_batch_by_id(%{id: batch_id}, actor: actor, authorize?: false),
        Orders.get_order_item_by_id(%{id: item_id},
          actor: actor,
          authorize?: false,
          load: [:product]
        )
      } do
        {{:ok, batch}, {:ok, item}} ->
          if batch.product_id == item.product_id,
            do: :ok,
            else: {:error, message: "allocation product must match batch product"}

        _ ->
          # Best-effort: skip hard failure if lookups unavailable in current context
          :ok
      end
    end
  end

  defp field(changeset, name) do
    Changeset.get_attribute(changeset, name) || Changeset.get_data(changeset, name)
  end
end
