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

    {:ok, item} = fetch_item(order_item_id, actor)

    if item.consumed_at do
      {:ok, :already_consumed}
    else
      with {:ok, order} <- fetch_order(item.order_id, actor),
           {:ok, bom} <- resolve_bom(item, actor),
           :ok <- process_consumption(item, order, bom, actor) do
        Orders.update_item(item, %{status: item.status, consumed_at: DateTime.utc_now()}, actor: actor)
      end
    end
  end

  defp fetch_item(order_item_id, actor) do
    item =
      Orders.get_order_item_by_id!(order_item_id,
        load: [product: [active_bom: [:rollup, components: [material: [:id, :unit, :sku]]]]],
        actor: actor
      )

    {:ok, item}
  end

  defp fetch_order(order_id, actor) do
    {:ok, Orders.get_order_by_id!(order_id, actor: actor)}
  end

  defp resolve_bom(item, actor) do
    bom =
      item
      |> preferred_bom(actor)
      |> maybe_load_bom(actor)

    {:ok, bom}
  end

  defp preferred_bom(item, actor) do
    case Map.get(item.product, :active_bom) do
      nil ->
        %{product_id: item.product_id}
        |> Catalog.list_boms_for_product!(actor: actor)
        |> List.first()

      bom ->
        bom
    end
  end

  defp maybe_load_bom(nil, _actor), do: nil

  defp maybe_load_bom(bom, actor) do
    Ash.load!(bom, [:rollup, components: [material: [:id]]], actor: actor)
  end

  defp process_consumption(item, order, bom, actor) do
    quantity = item.quantity || Decimal.new(0)

    case rollup_components(bom) do
      {:ok, components_map} -> consume_with_lots(item, order, components_map, quantity, actor)
      _ -> consume_without_lots(item, order, bom, quantity, actor)
    end
  end

  defp rollup_components(%{rollup: %{components_map: map}}) when map != %{}, do: {:ok, map}
  defp rollup_components(_), do: :error

  defp consume_with_lots(_item, _order, %{} = components_map, _qty, _actor) when map_size(components_map) == 0, do: :ok

  defp consume_with_lots(item, order, components_map, qty, actor) do
    Enum.each(components_map, fn {material_id, per_unit_str} ->
      per_unit = Decimal.new(per_unit_str)
      required_total = Decimal.mult(per_unit, qty)
      allocate_material(item, order, material_id, required_total, actor)
    end)

    :ok
  end

  defp allocate_material(item, order, material_id, required_total, actor) do
    lots = available_lots(material_id, actor)

    case lots do
      [] ->
        Inventory.adjust_stock(
          %{
            material_id: material_id,
            quantity: Decimal.mult(required_total, Decimal.new(-1)),
            reason: "Order #{order.reference} item consumption"
          },
          actor: actor
        )

      lots_list ->
        do_allocate(item, order, lots_list, required_total, actor)
    end
  end

  defp available_lots(material_id, actor) do
    Craftplan.Inventory.Lot
    |> Ash.Query.new()
    |> Ash.Query.filter(expr(material_id == ^material_id))
    |> Ash.read!(actor: actor, authorize?: false)
    |> Ash.load!([:current_stock], actor: actor, authorize?: false)
    |> Enum.sort_by(fn lot ->
      {lot.expiry_date || ~D[9999-12-31],
       lot.received_at ||
         DateTime.from_naive!(~N[0000-01-01 00:00:00], "Etc/UTC")}
    end)
  end

  defp do_allocate(_item, _order, [], _remaining, _actor), do: :ok

  defp do_allocate(item, order, [lot | rest], remaining, actor) do
    current = lot.current_stock || Decimal.new(0)
    take_qty = Decimal.min(current, remaining)

    apply_lot_consumption(lot, take_qty, item, order, actor)

    remaining
    |> Decimal.sub(take_qty)
    |> continue_allocation(item, order, rest, actor)
  end

  defp apply_lot_consumption(lot, take_qty, item, order, actor) do
    if Decimal.compare(take_qty, Decimal.new(0)) == :gt do
      Inventory.adjust_stock(
        %{
          material_id: lot.material_id,
          lot_id: lot.id,
          quantity: Decimal.mult(take_qty, Decimal.new(-1)),
          reason: "Order #{order.reference} item consumption"
        },
        actor: actor
      )

      Craftplan.Orders.OrderItemLot
      |> Ash.Changeset.for_create(:create, %{
        order_item_id: item.id,
        lot_id: lot.id,
        quantity_used: take_qty
      })
      |> Ash.create!(actor: actor, authorize?: false)

      :ok
    else
      :ok
    end
  end

  defp continue_allocation(remaining, item, order, lots, actor) do
    if Decimal.compare(remaining, Decimal.new(0)) == :gt do
      do_allocate(item, order, lots, remaining, actor)
    else
      :ok
    end
  end

  defp consume_without_lots(_item, _order, nil, _qty, _actor), do: :ok

  defp consume_without_lots(_item, order, bom, qty, actor) do
    bom.components
    |> List.wrap()
    |> Enum.filter(&(&1.component_type == :material))
    |> Enum.each(fn component ->
      required = Decimal.mult(component.quantity, qty)

      Inventory.adjust_stock(
        %{
          material_id: component.material.id,
          quantity: Decimal.mult(required, Decimal.new(-1)),
          reason: "Order #{order.reference} item consumption"
        },
        actor: actor
      )
    end)

    :ok
  end
end
