defmodule Craftplan.Inventory.PurchaseOrder do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  alias Ash.Changeset
  alias Craftplan.Inventory
  alias Craftplan.Inventory.PurchaseOrder.Types.Status
  alias Craftplan.Inventory.PurchaseOrderItem
  alias Decimal, as: D

  require Ash.Query

  json_api do
    type "purchase-order"

    routes do
      base("/purchase-orders")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :purchase_order

    queries do
      get(:get_purchase_order, :read)
      list(:list_purchase_orders, :list)
    end

    mutations do
      create :create_purchase_order, :create
      update :update_purchase_order, :update
    end
  end

  postgres do
    table "inventory_purchase_orders"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [inserted_at: :desc], load: [:supplier])
    end

    create :create do
      primary? true
      accept [:supplier_id, :status, :ordered_at]
      change set_attribute(:status, :draft)
    end

    update :update do
      accept [:supplier_id, :status, :ordered_at, :received_at]
    end

    update :receive do
      require_atomic? false

      argument :lot_receipts, {:array, :map} do
        allow_nil? true
        default []

        description """
        List of %{purchase_order_item_id?, material_id, lot_code, supplier_lot_code?, quantity,
        expiry_date?, unit_cost?}.
        If unit_cost is omitted, it falls back to the matching PurchaseOrderItem.unit_price.
        """
      end

      change before_action(fn changeset, _context ->
               actor = changeset.context[:private][:actor]
               receipts = Changeset.get_argument(changeset, :lot_receipts) || []

               items =
                 PurchaseOrderItem
                 |> Ash.Query.filter(purchase_order_id == ^changeset.data.id)
                 |> Ash.Query.load(lots: [:received_quantity])
                 |> Ash.read!(authorize?: false)

               with {:ok, receipts} <- prepare_lot_receipts(receipts, items),
                    :ok <- validate_receipt_quantities(receipts, items) do
                 changeset
                 |> Changeset.force_set_argument(:lot_receipts, receipts)
                 |> set_receipt_state(items, receipts)
               else
                 {:error, reason} ->
                   Changeset.add_error(changeset,
                     field: :lot_receipts,
                     message: to_string(reason)
                   )
               end
             end)

      change after_action(fn changeset, po, _ctx ->
               actor = changeset.context[:private][:actor]
               receipts = Changeset.get_argument(changeset, :lot_receipts) || []

               with :ok <- receive_lots(po, receipts, actor) do
                 {:ok, po}
               end
             end)
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reference, :string do
      writable? false
      allow_nil? false
      generated? true

      default fn ->
        dt = DateTime.utc_now()
        year = dt.year |> Integer.to_string() |> String.pad_leading(4, "0")
        month = dt.month |> Integer.to_string() |> String.pad_leading(2, "0")
        day = dt.day |> Integer.to_string() |> String.pad_leading(2, "0")
        rand = for _ <- 1..6, into: "", do: <<Enum.random(?A..?Z)>>
        "PO_#{year}_#{month}_#{day}_#{rand}"
      end

      constraints match: ~r/^PO_\d{4}_\d{2}_\d{2}_[A-Z]{6}$/,
                  allow_empty?: false
    end

    attribute :status, Status do
      allow_nil? false
      default :draft
    end

    attribute :ordered_at, :utc_datetime do
      allow_nil? true
    end

    attribute :received_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :supplier, Craftplan.Inventory.Supplier do
      allow_nil? false
    end

    has_many :items, PurchaseOrderItem
  end

  identities do
    identity :reference, [:reference]
  end

  defp prepare_lot_receipts(receipts, items) do
    context = %{
      items_by_id: Map.new(items, &{&1.id, &1}),
      unit_prices_by_material: unit_prices_by_material(items)
    }

    receipts
    |> Enum.reduce_while({:ok, []}, fn receipt, {:ok, acc} ->
      case prepare_lot_receipt(receipt, context) do
        {:ok, prepared} -> {:cont, {:ok, [prepared | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, prepared} -> {:ok, Enum.reverse(prepared)}
      error -> error
    end
  end

  defp prepare_lot_receipt(receipt, context) do
    material_id = receipt_value(receipt, :material_id)

    with {:ok, item_id} <- resolve_item_id(receipt, material_id, context),
         receipt = Map.put(receipt, :purchase_order_item_id, item_id),
         {:ok, quantity} <- normalize_positive_quantity(receipt_value(receipt, :quantity)),
         {:ok, lot_code} <-
           required_text(receipt_value(receipt, :lot_code), "lot_code is required"),
         {:ok, unit_cost} <- resolve_unit_cost(receipt, material_id, context) do
      {:ok,
       %{
         purchase_order_item_id: item_id,
         material_id: material_id,
         lot_code: lot_code,
         supplier_lot_code: blank_to_nil(receipt_value(receipt, :supplier_lot_code)),
         quantity: quantity,
         expiry_date: blank_to_nil(receipt_value(receipt, :expiry_date)),
         unit_cost: unit_cost
       }}
    end
  end

  defp resolve_item_id(receipt, material_id, %{items_by_id: items_by_id}) do
    case receipt_value(receipt, :purchase_order_item_id) do
      nil ->
        matching_ids =
          items_by_id
          |> Enum.filter(fn {_id, item} -> item.material_id == material_id end)
          |> Enum.map(&elem(&1, 0))

        case matching_ids do
          [item_id] ->
            {:ok, item_id}

          [] ->
            {:error, "receipt material does not belong to this purchase order"}

          _ ->
            {:error, "purchase_order_item_id is required when a material appears more than once"}
        end

      item_id ->
        case Map.fetch(items_by_id, item_id) do
          {:ok, %{material_id: ^material_id}} -> {:ok, item_id}
          {:ok, _item} -> {:error, "purchase_order_item_id does not match receipt material_id"}
          :error -> {:error, "purchase_order_item_id does not belong to this purchase order"}
        end
    end
  end

  defp resolve_unit_cost(receipt, material_id, context) do
    case receipt_value(receipt, :unit_cost) do
      nil -> fallback_unit_cost(receipt, material_id, context)
      unit_cost -> {:ok, unit_cost}
    end
  end

  defp fallback_unit_cost(receipt, material_id, %{items_by_id: items_by_id} = context) do
    case receipt_value(receipt, :purchase_order_item_id) do
      nil -> fallback_unit_cost_by_material(material_id, context)
      item_id -> fallback_unit_cost_by_item(item_id, material_id, items_by_id)
    end
  end

  defp fallback_unit_cost_by_item(item_id, material_id, items_by_id) do
    case Map.fetch(items_by_id, item_id) do
      {:ok, %{material_id: ^material_id, unit_price: unit_price}} ->
        {:ok, unit_price}

      {:ok, _item} ->
        {:error, "purchase_order_item_id does not match receipt material_id"}

      :error ->
        {:error, "purchase_order_item_id does not belong to this purchase order"}
    end
  end

  defp fallback_unit_cost_by_material(material_id, %{unit_prices_by_material: prices}) do
    case Map.get(prices, material_id) do
      {:ok, unit_price} ->
        {:ok, unit_price}

      :ambiguous ->
        {:error, "unit_cost is required when a purchase order has multiple prices for a material"}

      nil ->
        {:ok, nil}
    end
  end

  defp unit_prices_by_material(items) do
    items
    |> Enum.group_by(& &1.material_id)
    |> Map.new(fn {material_id, material_items} ->
      case unique_unit_prices(material_items) do
        [unit_price] -> {material_id, {:ok, unit_price}}
        _prices -> {material_id, :ambiguous}
      end
    end)
  end

  defp unique_unit_prices(items) do
    Enum.reduce(items, [], fn item, prices ->
      if Enum.any?(prices, &same_unit_price?(&1, item.unit_price)) do
        prices
      else
        [item.unit_price | prices]
      end
    end)
  end

  defp same_unit_price?(%D{} = left, %D{} = right), do: D.equal?(left, right)
  defp same_unit_price?(left, right), do: left == right

  defp receive_lots(po, receipts, actor) do
    Enum.reduce_while(receipts, :ok, fn receipt, :ok ->
      case receive_lot(po, receipt, actor) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp receive_lot(po, receipt, actor) do
    with {:ok, lot} <- create_lot(po, receipt, actor),
         {:ok, _movement} <-
           Inventory.adjust_stock(
             %{
               material_id: receipt.material_id,
               lot_id: lot.id,
               quantity: receipt.quantity,
               reason: "PO #{po.reference} receive"
             },
             actor: actor
           ) do
      :ok
    end
  end

  defp create_lot(po, receipt, actor) do
    Craftplan.Inventory.Lot
    |> Changeset.for_create(:create, %{
      lot_code: receipt.lot_code,
      supplier_lot_code: receipt.supplier_lot_code,
      received_quantity: receipt.quantity,
      material_id: receipt.material_id,
      supplier_id: po.supplier_id,
      purchase_order_item_id: receipt.purchase_order_item_id,
      received_at: DateTime.utc_now(),
      expiry_date: receipt.expiry_date,
      unit_cost: receipt.unit_cost
    })
    |> Ash.create(actor: actor)
  end

  defp receipt_value(receipt, key), do: Map.get(receipt, key) || Map.get(receipt, Atom.to_string(key))

  defp validate_receipt_quantities([], _items), do: {:error, "Add at least one lot to receive"}

  defp validate_receipt_quantities(receipts, items) do
    new_by_item =
      receipts
      |> Enum.group_by(& &1.purchase_order_item_id, & &1.quantity)
      |> Map.new(fn {item_id, quantities} ->
        {item_id, Enum.reduce(quantities, D.new(0), &D.add/2)}
      end)

    Enum.reduce_while(items, :ok, fn item, :ok ->
      received = received_quantity(item)
      incoming = Map.get(new_by_item, item.id, D.new(0))
      total = D.add(received, incoming)

      if D.gt?(total, item.quantity) do
        {:halt, {:error, "Received quantity for purchase order item #{item.id} exceeds the ordered quantity"}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp set_receipt_state(changeset, items, receipts) do
    incoming_by_item =
      receipts
      |> Enum.group_by(& &1.purchase_order_item_id, & &1.quantity)
      |> Map.new(fn {item_id, quantities} ->
        {item_id, Enum.reduce(quantities, D.new(0), &D.add/2)}
      end)

    complete? =
      Enum.all?(items, fn item ->
        total = D.add(received_quantity(item), Map.get(incoming_by_item, item.id, D.new(0)))
        D.equal?(total, item.quantity)
      end)

    if complete? do
      changeset
      |> Changeset.force_change_attribute(:status, :received)
      |> Changeset.force_change_attribute(:received_at, DateTime.utc_now())
    else
      Changeset.force_change_attribute(changeset, :status, :partially_received)
    end
  end

  defp received_quantity(item) do
    Enum.reduce(item.lots || [], D.new(0), fn lot, total ->
      D.add(total, lot.received_quantity || D.new(0))
    end)
  end

  defp normalize_positive_quantity(%D{} = quantity) do
    if D.gt?(quantity, D.new(0)), do: {:ok, quantity}, else: {:error, "quantity must be positive"}
  end

  defp normalize_positive_quantity(quantity) when is_binary(quantity) do
    normalize_positive_quantity(D.new(quantity))
  rescue
    _ -> {:error, "quantity must be a number"}
  end

  defp normalize_positive_quantity(_quantity), do: {:error, "quantity must be positive"}

  defp required_text(value, error) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, error}
      value -> {:ok, value}
    end
  end

  defp required_text(_value, error), do: {:error, error}

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
