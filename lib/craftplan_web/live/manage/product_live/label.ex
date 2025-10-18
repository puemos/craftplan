defmodule CraftplanWeb.ProductLive.Label do
  @moduledoc false
  use CraftplanWeb, :live_view

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
          <div class="font-medium">{Calendar.strftime(@today, "%Y-%m-%d")}</div>
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
          recipe: [components: [material: [:name]]]
        ],
        actor: socket.assigns[:current_user]
      )

    ingredients =
      case product.recipe do
        nil -> []
        recipe -> Enum.map(recipe.components, fn c -> c.material.name end)
      end

    {:ok,
     socket
     |> assign(:product, product)
     |> assign(:ingredients, ingredients)
     |> assign(:allergens, product.allergens || [])
     |> assign(:today, Date.utc_today())}
  end

  defp batch_code(date, sku) do
    "B-" <> Calendar.strftime(date, "%Y%m%d") <> "-" <> sku
  end
end
