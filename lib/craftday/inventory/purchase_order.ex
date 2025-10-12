defmodule Craftday.Inventory.PurchaseOrder do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftday.Inventory.PurchaseOrder.Types.Status

  postgres do
    table "inventory_purchase_orders"
    repo Craftday.Repo
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
    belongs_to :supplier, Craftday.Inventory.Supplier do
      allow_nil? false
    end

    has_many :items, Craftday.Inventory.PurchaseOrderItem
  end

  identities do
    identity :reference, [:reference]
  end
end
