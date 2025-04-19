defmodule Craftday.Cart.Item do
  @moduledoc """
  Represents an item in the shopping cart.
  """
  defstruct [:product, :quantity]

  def new(product, quantity) do
    %__MODULE__{
      product: product,
      quantity: quantity
    }
  end

  def increment(item, quantity) do
    %{item | quantity: item.quantity + quantity}
  end
end
