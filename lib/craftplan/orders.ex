defmodule Craftplan.Orders do
  @moduledoc false
  use Ash.Domain

  alias Craftplan.Orders.Order

  resources do
    resource Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
    end

    resource Craftplan.Orders.OrderItem do
      define :get_order_item_by_id, action: :read, get_by: [:id]
      define :update_item, action: :update
    end
  end

  @doc """
  Public fetch of an order by reference using the `:public_show` read action.
  Returns `{:ok, order_or_nil}`.
  """
  def public_get_order_by_reference(reference, opts \\ []) do
    load = Keyword.get(opts, :load, [])

    query =
      Order
      |> Ash.Query.for_read(:public_show, %{reference: reference})
      |> Ash.Query.load(load)

    case Ash.read_one(query) do
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:ok, nil}
    end
  end
end
