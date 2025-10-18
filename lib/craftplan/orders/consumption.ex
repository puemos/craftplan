defmodule Craftplan.Orders.Consumption do
  @moduledoc """
  Explicit consumption of materials for order items.
  """

  alias Craftplan.Inventory
  alias Craftplan.Orders

  @doc """
  Consume materials for a given order_item id if not already consumed.
  Returns {:ok, updated_item} or {:ok, :already_consumed}.
  """
  def consume_item(order_item_id, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    item =
      Orders.get_order_item_by_id!(order_item_id,
        load: [product: [:recipe, recipe: [components: [material: [:id, :unit, :sku]]]]],
        actor: actor
      )

    if item.consumed_at do
      {:ok, :already_consumed}
    else
      qty = item.quantity || Decimal.new(0)

      # Fetch order to include reference in movement reason
      order = Orders.get_order_by_id!(item.order_id, actor: actor)

      movements =
        case item.product.recipe do
          nil ->
            []

          recipe ->
            Enum.map(recipe.components, fn component ->
              required = Decimal.mult(component.quantity, qty)

              %{
                material_id: component.material.id,
                quantity: Decimal.mult(required, Decimal.new(-1)),
                reason: "Order #{order.reference} item consumption"
              }
            end)
        end

      Enum.each(movements, fn mv ->
        _ =
          Inventory.adjust_stock(
            %{
              material_id: mv.material_id,
              quantity: mv.quantity,
              reason: mv.reason
            },
            actor: actor
          )
      end)

      Orders.update_item(item, %{status: item.status, consumed_at: DateTime.utc_now()}, actor: actor)
    end
  end
end
