defmodule Craftplan.Types.Currency do
  @moduledoc false
  use Ash.Type.Enum,
      values: Money.Currency.known_current_currencies()
end
