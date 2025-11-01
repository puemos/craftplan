defmodule Craftplan.Catalog.BOMComponent do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer

  alias Craftplan.Catalog.Changes.ValidateComponentTarget
  alias Craftplan.Catalog.Services.BOMRollup

  postgres do
    table "catalog_bom_components"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :component_type,
        :quantity,
        :position,
        :waste_percent,
        :notes,
        :material_id,
        :product_id
      ]

      change {ValidateComponentTarget, []}

      change after_action(fn changeset, result, _ctx ->
               bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

               BOMRollup.refresh_by_bom_id!(
                 bom_id,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :component_type,
        :quantity,
        :position,
        :waste_percent,
        :notes,
        :material_id,
        :product_id
      ]

      change {ValidateComponentTarget, []}

      change after_action(fn changeset, result, _ctx ->
               bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

               BOMRollup.refresh_by_bom_id!(
                 bom_id,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :component_type, :atom do
      allow_nil? false
      default :material
      constraints one_of: [:material, :product]
    end

    attribute :quantity, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :waste_percent, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :notes, :string do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :bom, Craftplan.Catalog.BOM do
      allow_nil? false
    end

    belongs_to :material, Craftplan.Inventory.Material do
      allow_nil? true
      domain Craftplan.Inventory
    end

    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? true
    end
  end
end
