defmodule CraftplanWeb.ProductLive.Label do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Ash.NotLoaded
  alias Craftplan.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl bg-white p-6 print:m-0 print:max-w-full print:border-0 print:p-0 print:shadow-none">
      <div class="mb-4 flex items-start justify-between print:mb-2">
        <div>
          <h1 class="text-2xl font-semibold print:text-xl">Product Label</h1>
          <div class="text-sm text-stone-600">SKU: {@product.sku}</div>
        </div>
        <div class="text-right text-sm">
          <div class="text-stone-600">Date</div>
          <div class="font-medium">{format_date(@today, format: "%Y-%m-%d")}</div>
          <div class="mt-2 text-stone-600">Batch</div>
          <div class="font-medium">{batch_code(@today, @product.sku)}</div>
        </div>
      </div>

      <div class="mb-4">
        <div class="text-xl font-semibold print:text-lg">{@product.name}</div>
      </div>

      <div :if={@ingredients != []} class="mb-4">
        <div class="mb-1 text-sm font-medium text-stone-700">Ingredients</div>
        <ul class="list-inside list-disc text-sm">
          <li :for={name <- @ingredients}>{name}</li>
        </ul>
      </div>

      <div :if={@allergens != []} class="mb-4">
        <div class="mb-1 text-sm font-medium text-stone-700">Allergens</div>
        <div class="flex flex-wrap gap-2 text-sm">
          <.badge :for={a <- @allergens} text={a.name} />
        </div>
      </div>

      <div :if={nutrition_declaration?(@nutrition_facts)} class="mb-4">
        <div class="mb-1 text-sm font-medium text-stone-700">
          Nutrition declaration per {nutrition_basis_label(@nutrition_facts)}
        </div>
        <table class="w-full border-collapse text-sm">
          <tbody>
            <tr :for={fact <- @nutrition_facts} class="border-b border-stone-200">
              <td class="py-1 pr-4">
                <span class={if Map.get(fact, :parent_key), do: "pl-4", else: ""}>
                  {nutrient_label(fact)}
                </span>
              </td>
              <td class="py-1 text-right">{format_amount(fact.unit, fact.amount)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-6 flex justify-end print:hidden">
        <.button variant={:primary} onclick="window.print()">Print</.button>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"sku" => sku}, _session, socket) do
    product =
      Catalog.get_product_by_sku!(
        sku,
        load: [
          :name,
          :sku,
          :allergens,
          :nutritional_facts,
          active_bom: [components: [:component_type, material: [:name]]]
        ],
        actor: socket.assigns[:current_user]
      )

    bom_for_label =
      case product.active_bom do
        %NotLoaded{} ->
          nil

        nil ->
          %{product_id: product.id}
          |> Catalog.list_boms_for_product!(actor: socket.assigns[:current_user])
          |> List.first()

        bom ->
          bom
      end

    bom_for_label =
      case bom_for_label do
        nil ->
          nil

        b ->
          Ash.load!(b, [components: [:component_type, material: [:name, allergens: [:name]]]],
            actor: socket.assigns[:current_user]
          )
      end

    ingredients =
      case bom_for_label do
        nil ->
          []

        bom ->
          bom.components
          |> Enum.filter(&(&1.component_type == :material))
          |> Enum.map(fn component -> component.material.name end)
      end

    {:ok,
     socket
     |> assign(:product, product)
     |> assign(:ingredients, ingredients)
     |> assign(:nutrition_facts, product.nutritional_facts || [])
     |> assign(
       :allergens,
       (product.allergens != [] && product.allergens) ||
         (bom_for_label &&
            bom_for_label.components
            |> Enum.filter(&(&1.component_type == :material))
            |> Enum.flat_map(fn c -> Map.get(c.material, :allergens, []) end)
            |> Enum.uniq_by(& &1.name)
            |> Enum.sort_by(& &1.name)) || []
     )
     |> assign(:today, Date.utc_today())}
  end

  defp batch_code(date, sku) do
    "B-" <> format_date(date, format: "%Y%m%d") <> "-" <> sku
  end

  # no recipe fallback

  defp nutrition_declaration?(facts), do: Enum.any?(facts, &Map.get(&1, :declaration?, false))

  defp nutrition_basis_label(facts) do
    facts
    |> Enum.find(&Map.get(&1, :declaration?, false))
    |> case do
      %{per_quantity: quantity, per_unit: unit} ->
        "#{format_basis_quantity(quantity)} #{basis_unit_abbreviation(unit)}"

      _ ->
        "100 g"
    end
  end

  defp nutrient_label(%{parent_key: parent_key, name: name}) when not is_nil(parent_key) do
    "of which #{String.downcase(name)}"
  end

  defp nutrient_label(%{name: name}), do: name

  defp basis_unit_abbreviation(:milliliter), do: "ml"
  defp basis_unit_abbreviation("milliliter"), do: "ml"
  defp basis_unit_abbreviation(_unit), do: "g"

  defp format_basis_quantity(%Decimal{} = quantity) do
    quantity
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp format_basis_quantity(quantity), do: to_string(quantity)
end
