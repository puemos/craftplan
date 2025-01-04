defmodule Microcraft.Production.Task do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Production,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "production_tasks"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:product_id, :name, :status], update: [:status, :notes]]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 2
    end

    attribute :status, Microcraft.Production.Task.Types.Status do
      allow_nil? false
      default :pending
    end

    attribute :notes, :string do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Microcraft.Catalog.Product do
      allow_nil? false
    end
  end
end
