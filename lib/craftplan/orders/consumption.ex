defmodule Craftplan.Orders.Consumption do
  @moduledoc """
  Explicit consumption of materials for order items.
  """

  import Ash.Expr

  alias Craftplan.Catalog
  alias Craftplan.Inventory
  alias Craftplan.Orders

  require Ash.Query

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

      # Prefer flattened components to guide allocations
      _ =
        if bom && Map.get(bom, :rollup) && bom.rollup.components_map != %{} do
          allocate_and_consume_lots!(item, order, bom.rollup.components_map, qty, actor)
        else
          # Fallback: consume without lot tracking
          movements =
            (bom && Map.get(bom, :components) && bom.components) ||
              []
              |> Enum.filter(&(&1.component_type == :material))
              |> Enum.map(fn component ->
                required = Decimal.mult(component.quantity, qty)

                %{
                  material_id: component.material.id,
                  quantity: Decimal.mult(required, Decimal.new(-1)),
                  reason: "Order #{order.reference} item consumption"
                }
              end)

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
        end

      Orders.update_item(item, %{status: item.status, consumed_at: DateTime.utc_now()}, actor: actor)
    end
  end

  defp allocate_and_consume_lots!(item, order, components_map, qty, actor) do
    Enum.each(components_map, fn {material_id, per_unit_str} ->
      per_unit = Decimal.new(per_unit_str)
      required_total = Decimal.mult(per_unit, qty)
      remaining = required_total

      lots =
        Craftplan.Inventory.Lot
        |> Ash.Query.new()
        |> Ash.Query.filter(expr(material_id == ^material_id))
        |> Ash.read!(actor: actor, authorize?: false)
        |> Ash.load!([:current_stock], actor: actor, authorize?: false)
        |> Enum.sort_by(fn l ->
          {l.expiry_date || ~D[9999-12-31],
           l.received_at || DateTime.from_naive!(~N[0000-01-01 00:00:00], "Etc/UTC")}
        end)

      if Enum.empty?(lots) do
        # No lots exist for this material; fall back to non-lot stock adjustment
        _ =
          Inventory.adjust_stock(
            %{
              material_id: material_id,
              quantity: Decimal.mult(required_total, Decimal.new(-1)),
              reason: "Order #{order.reference} item consumption"
            },
            actor: actor
          )
      else
        do_allocate(item, order, lots, remaining, actor)
      end
    end)
  end

  defp do_allocate(_item, _order, [], _remaining, _actor), do: :ok

  defp do_allocate(item, order, [lot | rest], remaining, actor) do
    current = lot.current_stock || Decimal.new(0)

    take_qty =
      case Decimal.compare(current, remaining) do
        :lt -> current
        _ -> remaining
      end

    if Decimal.compare(take_qty, Decimal.new(0)) == :gt do
      # consume movement with lot
      _ =
        Inventory.adjust_stock(
          %{
            material_id: lot.material_id,
            lot_id: lot.id,
            quantity: Decimal.mult(take_qty, Decimal.new(-1)),
            reason: "Order #{order.reference} item consumption"
          },
          actor: actor
        )

      # persist allocation
      _ =
        Craftplan.Orders.OrderItemLot
        |> Ash.Changeset.for_create(:create, %{
          order_item_id: item.id,
          lot_id: lot.id,
          quantity_used: take_qty
        })
        |> Ash.create!(actor: actor, authorize?: false)
    end

    remaining2 = Decimal.sub(remaining, take_qty)

    if Decimal.compare(remaining2, Decimal.new(0)) == :gt do
      do_allocate(item, order, rest, remaining2, actor)
    else
      :ok
    end
  end
end
