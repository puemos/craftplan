defmodule Craftplan.Catalog.BOM do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  alias Craftplan.Catalog.Changes.AssignBOMVersion
  alias Craftplan.Catalog.Services.BOMRollup

  json_api do
    type "bom"

    routes do
      base("/boms")
      get(:read)
      index :list_for_product
    end
  end

  graphql do
    type :bom

    queries do
      get(:get_bom, :read)
      list(:list_boms, :list_for_product)
    end
  end

  postgres do
    table "catalog_boms"
    repo Craftplan.Repo

    custom_indexes do
      index [:product_id],
        unique: true,
        name: "catalog_boms_one_active_per_product",
        where: "status = 'active'"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [:name, :notes, :status, :product_id, :published_at]

      argument :components, {:array, :map}
      argument :labor_steps, {:array, :map}

      change manage_relationship(:components, type: :direct_control)
      change manage_relationship(:labor_steps, type: :direct_control)
      change {AssignBOMVersion, []}

      change after_action(fn changeset, result, _ctx ->
               BOMRollup.refresh!(result,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end

    update :update do
      require_atomic? false

      accept [:name, :notes, :status, :published_at]

      argument :components, {:array, :map}
      argument :labor_steps, {:array, :map}

      change manage_relationship(:components, type: :direct_control)
      change manage_relationship(:labor_steps, type: :direct_control)

      change after_action(fn changeset, result, _ctx ->
               BOMRollup.refresh!(result,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end

    update :promote do
      require_atomic? false

      change set_attribute(:status, :active)

      change fn cs, _ ->
        Ash.Changeset.change_attribute(cs, :published_at, DateTime.utc_now())
      end

      change after_action(fn changeset, result, _ctx ->
               BOMRollup.refresh!(result,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end

    read :list_for_product do
      argument :product_id, :uuid, allow_nil?: false

      prepare build(
                sort: [version: :desc],
                filter: expr(product_id == ^arg(:product_id))
              )
    end

    read :get_active do
      get? true

      argument :product_id, :uuid, allow_nil?: false

      prepare build(
                sort: [version: :desc],
                filter: expr(product_id == ^arg(:product_id) and status == :active)
              )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      constraints one_of: [:draft, :active, :archived]
      public? true
    end

    attribute :version, :integer do
      allow_nil? false
      writable? false
    end

    attribute :published_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? false
    end

    has_many :components, Craftplan.Catalog.BOMComponent

    has_many :labor_steps, Craftplan.Catalog.LaborStep

    has_one :rollup, Craftplan.Catalog.BOMRollup
  end

  identities do
    identity :product_version, [:product_id, :version]
  end
end
