defmodule Craftplan.Inventory.PurchaseOrder do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftplan.Inventory.PurchaseOrder.Types.Status

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
        description "List of %{material_id, lot_code, quantity, expiry_date?} to receive"
      end

      change set_attribute(:status, :received)
      change set_attribute(:received_at, &DateTime.utc_now/0)

      change after_action(fn changeset, po, _ctx ->
               actor = changeset.context[:actor]
               receipts = Ash.Changeset.get_argument(changeset, :lot_receipts) || []

               Enum.each(receipts, fn r ->
                 material_id = Map.get(r, :material_id) || Map.get(r, "material_id")
                 lot_code = Map.get(r, :lot_code) || Map.get(r, "lot_code")
                 expiry = Map.get(r, :expiry_date) || Map.get(r, "expiry_date")
                 qty = Map.get(r, :quantity) || Map.get(r, "quantity")

                 # Create/find lot
                 lot =
                   Ash.Seed.seed!(Craftplan.Inventory.Lot, %{
                     lot_code: lot_code,
                     material_id: material_id,
                     supplier_id: po.supplier_id,
                     received_at: DateTime.utc_now(),
                     expiry_date: expiry
                   })

                 # Create movement with lot
                 Craftplan.Inventory.adjust_stock(
                   %{
                     material_id: material_id,
                     lot_id: lot.id,
                     quantity: qty,
                     reason: "PO #{po.reference} receive"
                   },
                   actor: actor
                 )
               end)

               {:ok, po}
             end)
    end
  end

  policies do
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

    has_many :items, Craftplan.Inventory.PurchaseOrderItem
  end

  identities do
    identity :reference, [:reference]
  end
end
