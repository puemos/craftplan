defmodule Craftplan.Inventory.PurchaseOrder do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  require Ash.Query

  alias Craftplan.Inventory.PurchaseOrder.Types.Status

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
      update :receive_purchase_order, :receive
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
      accept [:supplier_id, :status, :ordered_at, :reference]
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
        List of %{material_id, lot_code, quantity, expiry_date?, unit_cost?} to receive.
        If unit_cost is omitted, it falls back to the matching PurchaseOrderItem.unit_price.
        """
      end

      argument :skip_bom_refresh, :boolean do
        allow_nil? true
        default false

        description """
        When true, skip the BOM cost-rollup refresh after this receive.
        Intended for chronological backfill scripts that import many POs in
        sequence and want to refresh BOM rollups once at the end instead of
        once per receive. Single-receive callers should leave this at false.
        """
      end

      change set_attribute(:status, :received)
      change set_attribute(:received_at, &DateTime.utc_now/0)

      change after_action(fn changeset, po, _ctx ->
               receipts = Ash.Changeset.get_argument(changeset, :lot_receipts) || []
               skip_bom_refresh = Ash.Changeset.get_argument(changeset, :skip_bom_refresh) == true

               # Direct read of PO items — at this point we're inside an after_action
               # on the PO update; loading the items relationship via Ash.load came
               # back empty even when items exist in the DB. Direct query is reliable.
               items =
                 Craftplan.Inventory.PurchaseOrderItem
                 |> Ash.Query.filter(purchase_order_id == ^po.id)
                 |> Ash.read!(authorize?: false)

               unit_price_by_material =
                 Map.new(items, fn item ->
                   {item.material_id, item.unit_price}
                 end)

               # Lots + movements are implementation detail of :receive. The outer
               # :receive action is already authorized; these inner writes run
               # without authorization so they don't depend on actor being threaded
               # through the changeset context (which is unreliable across callers).
               Enum.each(receipts, fn r ->
                 material_id = Map.get(r, :material_id) || Map.get(r, "material_id")
                 lot_code = Map.get(r, :lot_code) || Map.get(r, "lot_code")
                 expiry = Map.get(r, :expiry_date) || Map.get(r, "expiry_date")
                 qty = Map.get(r, :quantity) || Map.get(r, "quantity")

                 unit_cost =
                   Map.get(r, :unit_cost) || Map.get(r, "unit_cost") ||
                     Map.get(unit_price_by_material, material_id)

                 lot =
                   Ash.Seed.seed!(Craftplan.Inventory.Lot, %{
                     lot_code: lot_code,
                     material_id: material_id,
                     supplier_id: po.supplier_id,
                     received_at: DateTime.utc_now(),
                     expiry_date: expiry,
                     unit_cost: unit_cost
                   })

                 Craftplan.Inventory.adjust_stock(
                   %{
                     material_id: material_id,
                     lot_id: lot.id,
                     quantity: qty,
                     reason: "PO #{po.reference} receive"
                   },
                   authorize?: false
                 )
               end)

               # Update each unique material's price from the most-recent lot's
               # unit_cost ("last receive wins"). Bypass the rollup refresh on
               # each Material.update so it doesn't fire N times; do one bulk
               # refresh below for the unique materials affected.
               unique_material_costs =
                 receipts
                 |> Enum.map(fn r ->
                   material_id = Map.get(r, :material_id) || Map.get(r, "material_id")

                   unit_cost =
                     Map.get(r, :unit_cost) || Map.get(r, "unit_cost") ||
                       Map.get(unit_price_by_material, material_id)

                   {material_id, unit_cost}
                 end)
                 |> Enum.filter(fn {_id, cost} -> not is_nil(cost) end)
                 |> Map.new()

               Enum.each(unique_material_costs, fn {material_id, unit_cost} ->
                 material =
                   Craftplan.Inventory.Material
                   |> Ash.get!(material_id, authorize?: false)

                 material
                 |> Ash.Changeset.for_update(:update, %{price: unit_cost})
                 |> Ash.Changeset.set_context(%{bypass_bom_refresh?: true})
                 |> Ash.update!(authorize?: false)
               end)

               unless skip_bom_refresh do
                 unique_material_costs
                 |> Map.keys()
                 |> Enum.each(fn material_id ->
                   Craftplan.Inventory.Changes.RefreshAffectedBomRollups.refresh_for_material!(
                     material_id
                   )
                 end)
               end

               {:ok, po}
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
      public? true
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

      # Permissive constraint so callers (e.g. invoice importers) can pass a
      # vendor-specific reference like IGF-7367700-2026-06-16 instead of the
      # auto-generated PO_YYYY_MM_DD_XXXXXX. Identity on :reference still
      # enforces uniqueness.
      constraints match: ~r/^[A-Za-z0-9_\-]{3,64}$/,
                  allow_empty?: false
    end

    attribute :status, Status do
      public? true
      allow_nil? false
      default :draft
    end

    attribute :ordered_at, :utc_datetime do
      public? true
      allow_nil? true
    end

    attribute :received_at, :utc_datetime do
      public? true
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :supplier, Craftplan.Inventory.Supplier do
      allow_nil? false
    end

    has_many :items, Craftplan.Inventory.PurchaseOrderItem
  end

  identities do
    identity :reference, [:reference]
  end
end
