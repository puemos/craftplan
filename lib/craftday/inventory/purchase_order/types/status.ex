defmodule Craftday.Inventory.PurchaseOrder.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:draft, :ordered, :received]
end
