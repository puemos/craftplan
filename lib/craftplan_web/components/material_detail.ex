defmodule CraftplanWeb.Components.MaterialDetail do
  @moduledoc false
  use CraftplanWeb, :html

  attr :material, :any, required: true
  attr :active, :atom, required: true
  slot :actions, required: true

  def material_header(assigns) do
    assigns = assign(assigns, :links, tabs(assigns.material, assigns.active))

    ~H"""
    <.header>
      {@material.name}
      <:actions>{render_slot(@actions)}</:actions>
    </.header>
    <.sub_nav links={@links} />
    """
  end

  defp tabs(material, active) do
    [
      %{
        label: "Details",
        navigate: ~p"/manage/inventory/#{material.sku}/details",
        active: active in [:details, :show]
      },
      %{
        label: "Allergens",
        navigate: ~p"/manage/inventory/#{material.sku}/allergens",
        active: active == :allergens
      },
      %{
        label: "Nutrition",
        navigate: ~p"/manage/inventory/#{material.sku}/nutritional_facts",
        active: active == :nutritional_facts
      },
      %{
        label: "Stock",
        navigate: ~p"/manage/inventory/#{material.sku}/stock",
        active: active == :stock
      },
      %{
        label: "Production",
        navigate: ~p"/manage/inventory/#{material.sku}/production",
        active: active == :production
      }
    ]
  end
end
