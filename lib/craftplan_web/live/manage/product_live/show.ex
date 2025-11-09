defmodule CraftplanWeb.ProductLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@product.name}
      <:actions>
        <.link patch={~p"/manage/products/#{@product.sku}/edit"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Edit product</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-6 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <.list>
          <:item title="Status">
            <.badge
              text={@product.status}
              colors={[
                {@product.status,
                 "#{product_status_color(@product.status)} #{product_status_bg(@product.status)}"}
              ]}
            />
          </:item>
          <:item title="Availability">
            <.badge text={@product.selling_availability} />
          </:item>
          <:item title="Name">{@product.name}</:item>

          <:item title="SKU">
            <.kbd>
              {@product.sku}
            </.kbd>
          </:item>

          <:item title="Allergens">
            <div class="flex-inline items-center space-x-1">
              <.badge :for={allergen <- Enum.map(@product.allergens, & &1.name)} text={allergen} />
              <span :if={Enum.empty?(@product.allergens)}>None</span>
            </div>
          </:item>

          <:item title="Price">
            {format_money(@settings.currency, @product.price)}
          </:item>

          <:item title="Materials cost">
            {format_money(@settings.currency, @product.materials_cost)}
          </:item>

          <:item title="Gross profit">
            {format_money(@settings.currency, @product.gross_profit)}
          </:item>

          <:item title="Markup percentage">
            {format_percentage(@product.markup_percentage)}%
          </:item>

          <:item title="Suggested Prices">
            <div class="space-y-1">
              <div>
                <span class="text-stone-500">Retail:</span>
                <span class="ml-2 font-medium">
                  {format_money(
                    @settings.currency,
                    suggested_price(:retail, @product.bom_unit_cost, @settings)
                  )}
                </span>
              </div>
              <div>
                <span class="text-stone-500">Wholesale:</span>
                <span class="ml-2 font-medium">
                  {format_money(
                    @settings.currency,
                    suggested_price(:wholesale, @product.bom_unit_cost, @settings)
                  )}
                </span>
              </div>
            </div>
          </:item>

          <:item
            :if={@product.max_daily_quantity && @product.max_daily_quantity > 0}
            title="Max units per day"
          >
            {@product.max_daily_quantity}
          </:item>
        </.list>
      </.tabs_content>

      <.tabs_content :if={@live_action == :recipe}>
        <.live_component
          module={CraftplanWeb.ProductLive.FormComponentRecipe}
          id="material-form"
          product={@product}
          current_user={@current_user}
          settings={@settings}
          materials={@materials_available}
          selected_version={@selected_bom_version}
          patch={~p"/manage/products/#{@product.sku}/recipe"}
          on_cancel={hide_modal("product-material-modal")}
        />
      </.tabs_content>

      <.tabs_content :if={@live_action == :nutrition}>
        <div>
          <h3 class="my-4 text-lg font-medium">Nutritional Facts</h3>
          <p class="mb-4 text-sm text-stone-500">
            The nutritional information is automatically calculated from your recipe components.
          </p>
        </div>
        <.table id="nutritional-facts" rows={@product.nutritional_facts}>
          <:col :let={fact} label="Nutrient">{fact.name}</:col>
          <:col :let={fact} label="Amount">{format_amount(fact.unit, fact.amount)}</:col>
        </.table>
      </.tabs_content>

      <.tabs_content :if={@live_action == :photos}>
        <.live_component
          module={CraftplanWeb.ProductLive.FormComponentPhotos}
          id={@product.id}
          title={@page_title}
          action={@live_action}
          current_user={@current_user}
          product={@product}
          settings={@settings}
          patch={~p"/manage/products/#{@product.sku}"}
        />
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      title={@page_title}
      description="Update product information and details."
      show
      on_cancel={JS.patch(~p"/manage/products/#{@product.sku}")}
    >
      <.live_component
        module={CraftplanWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        product={@product}
        settings={@settings}
        patch={~p"/manage/products/#{@product.sku}/details"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       materials_available: list_available_materials()
     )}
  end

  @impl true
  def handle_params(%{"sku" => sku} = params, _, socket) do
    product =
      Craftplan.Catalog.get_product_by_sku!(sku,
        load: [
          :markup_percentage,
          :gross_profit,
          :materials_cost,
          :allergens,
          :nutritional_facts,
          :bom_unit_cost,
          active_bom: [:rollup, components: [:material, :product], labor_steps: []]
        ]
      )

    live_action = socket.assigns.live_action

    selected_bom_version =
      case Map.get(params, "v") do
        v when is_binary(v) ->
          case Integer.parse(v) do
            {ver, _} -> ver
            _ -> nil
          end

        _ ->
          nil
      end

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/products/#{product.sku}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Recipe",
        navigate: ~p"/manage/products/#{product.sku}/recipe",
        active: live_action == :recipe
      },
      %{
        label: "Nutrition",
        navigate: ~p"/manage/products/#{product.sku}/nutrition",
        active: live_action == :nutrition
      },
      %{
        label: "Photos",
        navigate: ~p"/manage/products/#{product.sku}/photos",
        active: live_action == :photos
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:product, product)
      |> assign(:selected_bom_version, selected_bom_version)
      |> assign(:status_form, to_form(%{"status" => product.status}))
      |> assign(:tabs_links, tabs_links)
      |> assign(:breadcrumbs, product_breadcrumbs(product, live_action))

    {:noreply, socket}
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponentPhotos, {:saved, _}}, socket) do
    product =
      Craftplan.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :bom_unit_cost,
          active_bom: [components: [:material, :product], labor_steps: []]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Photos updated successfully")
     |> assign(:product, product)}
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponentRecipe, {:saved, _}}, socket) do
    product =
      Craftplan.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          :bom_unit_cost,
          active_bom: [components: [:material, :product], labor_steps: []]
        ],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> put_flash(:info, "Recipe updated successfully")
     |> assign(:product, product)
     |> push_event("close-modal", %{id: "product-material-modal"})}
  end

  def handle_info({CraftplanWeb.ProductLive.FormComponent, {:saved, _}}, socket) do
    product =
      Craftplan.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          :bom_unit_cost
        ],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> put_flash(:info, "Product updated successfully")
     |> assign(:product, product)}
  end

  @impl true
  def handle_event("product-status-change", %{"_target" => ["status"], "status" => status}, socket) do
    case Ash.update(socket.assigns.product, %{status: status}, actor: socket.assigns.current_user) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> assign(:product, product)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp page_title(:show), do: "Product"
  defp page_title(:nutrition), do: "Product Nutritional Information"
  defp page_title(:edit), do: "Modify Product"
  defp page_title(:recipe), do: "Product Recipe"
  defp page_title(:details), do: "Product"
  defp page_title(_), do: "Product"

  defp product_breadcrumbs(product, live_action) do
    base = [
      %{label: "Products", path: ~p"/manage/products", current?: false},
      %{
        label: product.name,
        path: ~p"/manage/products/#{product.sku}",
        current?: live_action in [:show, :details]
      }
    ]

    case live_action do
      :recipe ->
        base ++
          [
            %{label: "Recipe", path: ~p"/manage/products/#{product.sku}/recipe", current?: true}
          ]

      :nutrition ->
        base ++
          [
            %{
              label: "Nutrition",
              path: ~p"/manage/products/#{product.sku}/nutrition",
              current?: true
            }
          ]

      :photos ->
        base ++
          [
            %{label: "Photos", path: ~p"/manage/products/#{product.sku}/photos", current?: true}
          ]

      _ ->
        List.update_at(base, 1, &Map.put(&1, :current?, true))
    end
  end

  defp list_available_materials do
    Inventory.list_materials!()
  end

  # Pricing helper
  defp suggested_price(:retail, unit_cost, settings) do
    apply_markup(unit_cost, settings.retail_markup_mode, settings.retail_markup_value)
  end

  defp suggested_price(:wholesale, unit_cost, settings) do
    apply_markup(unit_cost, settings.wholesale_markup_mode, settings.wholesale_markup_value)
  end

  defp apply_markup(unit_cost, mode, value) do
    unit = unit_cost || Decimal.new(0)
    val = value || Decimal.new(0)

    case mode do
      :percent ->
        Decimal.add(unit, Decimal.mult(unit, Decimal.div(val, Decimal.new(100))))

      :fixed ->
        Decimal.add(unit, val)

      _ ->
        unit
    end
  end
end
