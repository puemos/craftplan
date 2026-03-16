defmodule Craftplan.Seed do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      use PhilColumns.Seed
    end
  end
end
