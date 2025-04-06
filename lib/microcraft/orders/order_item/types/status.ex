defmodule Microcraft.Orders.OrderItem.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :todo,
      :in_process,
      :done
    ]
end
