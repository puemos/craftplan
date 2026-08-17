defmodule Craftplan.Inventory.Receiving do
  @moduledoc """
  Service for receiving purchase orders into stock.
  """

  alias Craftplan.Inventory

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
          items: [:quantity, :unit_price, :material_id]
        ],
        actor: actor
      )

    if po.received_at do
      {:ok, :already_received}
    else
      Inventory.receive_purchase_order(po, %{lot_receipts: lot_receipts(po)}, actor: actor)
    end
  end

  defp lot_receipts(po) do
    po.items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, line_number} ->
      %{
        purchase_order_item_id: item.id,
        material_id: item.material_id,
        lot_code: "#{po.reference}-L#{line_number}",
        quantity: item.quantity
      }
    end)
  end
end
