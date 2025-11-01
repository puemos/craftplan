defmodule Craftplan.Catalog.Changes.ValidateComponentTarget do
  @moduledoc false

  use Ash.Resource.Change

  import Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    type = get_attribute(changeset, :component_type) || changeset.data.component_type

    case type do
      :material ->
        ensure_present(
          changeset,
          :material_id,
          "must reference a material when component_type is :material"
        )

      :product ->
        ensure_present(
          changeset,
          :product_id,
          "must reference a product when component_type is :product"
        )

      _ ->
        add_error(changeset, field: :component_type, message: "is invalid")
    end
  end

  defp ensure_present(changeset, field, message) do
    value = get_attribute(changeset, field) || Map.get(changeset.data, field)

    if is_nil(value) do
      add_error(changeset, field: field, message: message)
    else
      changeset
    end
  end
end
