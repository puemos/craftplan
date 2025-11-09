defmodule Craftplan.Orders.ProductionBatch do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ash.Expr

  postgres do
    table "orders_production_batches"
    repo Craftplan.Repo

    custom_indexes do
      index [:batch_code], unique: true, name: "orders_production_batches_batch_code_index"
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:batch_code, :produced_at, :product_id, :bom_id]
    ]

    read :by_code do
      argument :batch_code, :string, allow_nil?: false
      get? true
      filter expr(batch_code == ^arg(:batch_code))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :batch_code, :string do
      allow_nil? false
    end

    attribute :produced_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? false
    end

    belongs_to :bom, Craftplan.Catalog.BOM do
      allow_nil? true
    end

    has_many :order_items, Craftplan.Orders.OrderItem
  end
end
