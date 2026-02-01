defmodule Craftplan.Orders.ProductionBatch do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  import Ash.Expr

  alias Craftplan.Orders.Changes.BatchOpenInit

  require Ash.Query

  json_api do
    type "production-batch"

    routes do
      base("/production-batches")
      get(:read)
      index :read
    end
  end

  graphql do
    type :production_batch

    queries do
      get(:get_production_batch, :read)
      list(:list_production_batches, :read)
    end
  end

  postgres do
    table "orders_production_batches"
    repo Craftplan.Repo

    custom_indexes do
      index [:batch_code], unique: true, name: "orders_production_batches_batch_code_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :open do
      accept [:product_id, :planned_qty, :notes]
      change {BatchOpenInit, []}
    end

    create :open_with_allocations do
      accept [:product_id, :planned_qty, :notes]
      argument :allocations, {:array, :map}, allow_nil?: true
      change {BatchOpenInit, []}
      change manage_relationship(:allocations, type: :direct_control)
    end

    update :start do
      accept []
      change set_attribute(:status, :in_progress)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :consume do
      argument :lot_plan, :map, allow_nil?: false
      require_atomic? false
      change {Craftplan.Orders.Changes.BatchConsume, []}
    end

    update :complete do
      argument :produced_qty, :decimal, allow_nil?: false
      argument :duration_minutes, :decimal, allow_nil?: true
      argument :completed_map, :map, allow_nil?: true
      argument :lot_plan, :map, allow_nil?: true
      require_atomic? false
      change {Craftplan.Orders.Changes.BatchComplete, []}
    end

    read :by_code do
      argument :batch_code, :string, allow_nil?: false
      get? true
      filter expr(batch_code == ^arg(:batch_code))
    end

    read :list do
      argument :status, {:array, :atom}, allow_nil?: true
      argument :product_name, :string, allow_nil?: true

      prepare fn query, _context ->
        query = Ash.Query.sort(query, inserted_at: :desc)
        query = Ash.Query.load(query, [:product])

        query =
          case Ash.Query.get_argument(query, :status) do
            nil -> query
            [] -> query
            statuses -> Ash.Query.filter(query, expr(status in ^statuses))
          end

        case Ash.Query.get_argument(query, :product_name) do
          nil -> query
          "" -> query
          name -> Ash.Query.filter(query, expr(product.name == ^name))
        end
      end

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :recent do
      prepare build(sort: [inserted_at: :desc])

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :detail do
      argument :batch_code, :string, allow_nil?: false
      get? true

      prepare build(
                load: [
                  :product,
                  :bom,
                  allocations: [order_item: [:order, :product]],
                  batch_lots: [lot: [material: [:name, :unit], supplier: [:name]]]
                ]
              )

      filter expr(batch_code == ^arg(:batch_code))
    end

    read :plan do
      prepare build(
                load: [:product],
                filter: expr(status in [:open, :in_progress, :completed]),
                sort: [inserted_at: :desc]
              )
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

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

    # Planning and execution
    attribute :planned_qty, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :produced_qty, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :scrap_qty, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :status, :atom do
      allow_nil? false
      default :open
      constraints one_of: [:open, :in_progress, :completed, :canceled]
    end

    attribute :notes, :string do
      allow_nil? true
    end

    # Snapshot at batch creation
    attribute :bom_version, :integer do
      allow_nil? true
    end

    attribute :components_map, :map do
      allow_nil? false
      default %{}
    end

    # Timestamps
    attribute :started_at, :utc_datetime do
      allow_nil? true
    end

    attribute :completed_at, :utc_datetime do
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

    has_many :allocations, Craftplan.Orders.OrderItemBatchAllocation
    has_many :batch_lots, Craftplan.Orders.ProductionBatchLot
  end
end
