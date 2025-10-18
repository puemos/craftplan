defmodule Craftplan.Orders.OrderItem.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :todo,
      :in_progress,
      :done
    ]

  def match(:todo), do: {:ok, :todo}
  def match("todo"), do: {:ok, :todo}
  def match(:in_progress), do: {:ok, :in_progress}
  def match("in_progress"), do: {:ok, :in_progress}
  def match(:done), do: {:ok, :done}
  def match("done"), do: {:ok, :done}
  def match(value), do: super(value)
end
