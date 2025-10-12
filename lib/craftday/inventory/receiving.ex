defmodule Craftday.Inventory.Receiving do
  @moduledoc """
  Service for receiving purchase orders into stock.
  """

  alias Craftday.Inventory

  @doc """
  Receive a purchase order by id.

  Creates positive inventory movements for each item and marks the PO as received.
  Idempotent: if `received_at` is set, returns `{:ok, :already_received}`.
  """
  def receive_po(po_id, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    po =
      Inventory.get_purchase_order_by_id!(po_id,
        load: [
          :reference,
          :status,
          :received_at,
          items: [:quantity, :material_id]
        ],
        actor: actor
      )

    if po.received_at do
      {:ok, :already_received}
    else
      Enum.each(po.items, fn item ->
        _ =
          Inventory.adjust_stock(
            %{
              material_id: item.material_id,
              quantity: item.quantity,
              reason: "Purchase order #{po.reference} received"
            },
            actor: actor
          )
      end)

      Inventory.update_purchase_order(po, %{status: :received, received_at: DateTime.utc_now()}, actor: actor)
    end
  end
end
