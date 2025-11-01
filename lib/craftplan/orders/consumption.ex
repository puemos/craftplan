defmodule Craftplan.Orders.Consumption do
  @moduledoc """
  Explicit consumption of materials for order items.
  """

  alias Craftplan.Catalog
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
        load: [product: [active_bom: [:rollup, components: [material: [:id, :unit, :sku]]]]],
        actor: actor
      )

    if item.consumed_at do
      {:ok, :already_consumed}
    else
      qty = item.quantity || Decimal.new(0)

      # Fetch order to include reference in movement reason
      order = Orders.get_order_by_id!(item.order_id, actor: actor)

      # Prefer the active BOM; if none, fall back to the latest BOM for the product
      case_result =
        case item.product.active_bom do
          nil ->
            %{product_id: item.product_id}
            |> Catalog.list_boms_for_product!(actor: actor)
            |> List.first()

          bom ->
            bom
        end

      bom =
        case case_result do
          nil -> nil
          b -> Ash.load!(b, [:rollup, components: [material: [:id]]], actor: actor)
        end

      movements =
        cond do
          bom && Map.get(bom, :rollup) && bom.rollup.components_map != %{} ->
            # Prefer persisted flattened components when available
            Enum.map(bom.rollup.components_map, fn {material_id, per_unit_str} ->
              per_unit = Decimal.new(per_unit_str)
              required = Decimal.mult(per_unit, qty)

              %{
                material_id: material_id,
                quantity: Decimal.mult(required, Decimal.new(-1)),
                reason: "Order #{order.reference} item consumption"
              }
            end)

          bom && Map.get(bom, :components) != nil ->
            # Fallback to direct components on the active BOM
            bom.components
            |> Enum.filter(&(&1.component_type == :material))
            |> Enum.map(fn component ->
              required = Decimal.mult(component.quantity, qty)

              %{
                material_id: component.material.id,
                quantity: Decimal.mult(required, Decimal.new(-1)),
                reason: "Order #{order.reference} item consumption"
              }
            end)

          true ->
            []
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
