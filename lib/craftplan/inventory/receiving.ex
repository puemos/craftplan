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
          items: [:quantity, :unit_price, :material_id, lots: [:received_quantity]]
        ],
        actor: actor
      )

    if po.status == :received or po.received_at do
      {:ok, :already_received}
    else
      receipts = Keyword.get(opts, :lot_receipts, lot_receipts(po))
      Inventory.receive_purchase_order(po, %{lot_receipts: receipts}, actor: actor)
    end
  end

  defp lot_receipts(po) do
    po.items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, line_number} ->
      received =
        Enum.reduce(item.lots || [], Decimal.new(0), fn lot, total ->
          Decimal.add(total, lot.received_quantity || Decimal.new(0))
        end)

      remaining = Decimal.sub(item.quantity, received)

      if Decimal.gt?(remaining, Decimal.new(0)) do
        sequence =
          item.lots
          |> length()
          |> Kernel.+(1)
          |> Integer.to_string()
          |> String.pad_leading(2, "0")

        [
          %{
            purchase_order_item_id: item.id,
            material_id: item.material_id,
            lot_code: "#{po.reference}-L#{line_number}-#{sequence}",
            quantity: remaining
          }
        ]
      else
        []
      end
    end)
  end
end
