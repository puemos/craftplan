defmodule Microcraft.Production.Task.Types.Status do
  use Ash.Type.Enum, values: [:pending, :in_progress, :done, :cancelled]
end
