defmodule Craftday.Inventory.MaterialAllergen do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_material_allergen"
    repo Craftday.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:allergen_id, :material_id]
    end
  end

  policies do
    # Public read (used for storefront allergen listing)
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  relationships do
    belongs_to :material, Craftday.Inventory.Material, primary_key?: true, allow_nil?: false
    belongs_to :allergen, Craftday.Inventory.Allergen, primary_key?: true, allow_nil?: false
  end
end
