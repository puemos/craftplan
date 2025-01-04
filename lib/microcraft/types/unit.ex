defmodule Microcraft.Types.Unit do
  @moduledoc false
  use Ash.Type.Enum, values: [:gram, :milliliter, :piece]
end
