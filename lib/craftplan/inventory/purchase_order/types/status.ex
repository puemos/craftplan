defmodule Craftplan.Inventory.PurchaseOrder.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:draft, :ordered, :partially_received, :received]
end
