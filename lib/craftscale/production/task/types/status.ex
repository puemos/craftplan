defmodule CraftScale.Production.Task.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:pending, :in_progress, :done, :cancelled]
end
