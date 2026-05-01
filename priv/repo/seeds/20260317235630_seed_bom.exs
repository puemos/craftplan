defmodule Craftplan.Repo.Seeds.SeedBom do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    products = Craftplan.Catalog.list_products!(authorize?: false)
    materials = Craftplan.Inventory.list_materials!(authorize?: false)

    labor_types = [
      "Mix & knead",
      "Bake loaves",
      "Bulk proof",
      "Bake",
      "Fill tins",
      "Laminate butter",
      "Proof",
      "Pipe",
      "Frost & decorate",
      "Bake Layers",
      "Cream butter & sugar",
      "Fold dry ingredients",
      "Prepare filling",
      "Frost & finish",
      "Bake tests",
      "Prep dough"
    ]

    labor_defs =
      Enum.map(labor_types, fn x ->
        %{
          name: x,
          duration_minutes: Decimal.new(Enum.random(1..25)),
          units_per_run: Decimal.new(Enum.random(1..25))
        }
      end)

    component_defs =
      Enum.map(materials, fn x ->
        %{
          component_type: :material,
          material_id: x.id,
          quantity: Decimal.new(Enum.random(1..25))
        }
      end)

    Enum.each(1..25, fn _ ->
      product = Enum.random(products)
      opts = [status: :active, name: "#{product.name}_v1"]

      component_defs = Enum.take(component_defs, Enum.random(1..Enum.count(component_defs)))
      labor_defs = Enum.take(labor_defs, Enum.random(1..Enum.count(labor_defs)))

      status = Keyword.get(opts, :status, :draft)

      published_at =
        case Keyword.get(opts, :published_at) do
          nil ->
            if status == :active do
              DateTime.utc_now()
            end

          value ->
            value
        end

      components =
        component_defs
        |> Enum.with_index(1)
        |> Enum.map(fn {attrs, position} ->
          Map.put(attrs, :position, position)
        end)

      labor_steps =
        labor_defs
        |> Enum.with_index(1)
        |> Enum.map(fn {attrs, sequence} ->
          attrs
          |> Map.put(:sequence, sequence)
          |> Map.put_new(:units_per_run, Decimal.new("1"))
        end)

      Catalog.BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        name: Keyword.get(opts, :name, "#{product.name} BOM"),
        status: status,
        published_at: published_at,
        components: components,
        labor_steps: labor_steps
      })
      |> Ash.create!(authorize?: false)
    end)
  end
end
