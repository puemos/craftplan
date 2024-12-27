defmodule MicrocraftWeb.ProductLive.Show do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@product.name}
      <:subtitle>
        <.breadcrumb>
          <:crumb label="Products" path={~p"/backoffice/products"} current?={false} />
          <:crumb
            label={@product.name}
            path={~p"/backoffice/products/#{@product.id}"}
            current?={true}
          />
        </.breadcrumb>
      </:subtitle>
      <:actions>
        <.link patch={~p"/backoffice/products/#{@product.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit product</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="product-tabs">
        <:tab
          label="Details"
          path={~p"/backoffice/products/#{@product.id}?page=details"}
          selected?={@page == "details"}
        >
          <.list>
            <:item title="Status">
              <div class="-mt-2 cursor-default">
                <.form for={@status_form} id="product-status-form">
                  <.input
                    name={@status_form[:status].name}
                    value={Atom.to_string(@product.status)}
                    type="segmented"
                    disabled={true}
                    options={[
                      {"Idea", :idea},
                      {"Experiment", :experiment},
                      {"For Sale", :for_sale},
                      {"Archived", :archived}
                    ]}
                  />
                </.form>
              </div>
            </:item>
            <:item title="Name">{@product.name}</:item>

            <:item title="SKU">{@product.sku}</:item>

            <:item title="Price">
              {Money.from_float!(:USD, Decimal.to_float(@product.price))}
            </:item>

            <:item title="Estimated Cost">
              {Money.from_float!(:USD, Decimal.to_float(@product.estimated_cost || Decimal.new(0)))}
            </:item>

            <:item title="Profit margin">
              {(@product.profit_margin || Decimal.new(0)) |> Decimal.mult(100) |> Decimal.normalize()}%
            </:item>
          </.list>
        </:tab>

        <:tab
          label="Recipe"
          path={~p"/backoffice/products/#{@product.id}?page=recipe"}
          selected?={@page == "recipe"}
        >
          <.button phx-click={show_modal("product-material-modal")}>
            <span :if={@product.recipe == nil}>Create recipe</span>
            <span :if={@product.recipe != nil}>Edit recipe</span>
          </.button>
          <div :if={@product.recipe} class="mt-8">
            <.label>Instructions</.label>
            <p class="text-sm mt-4">
              {@product.recipe.instructions}
            </p>

            <div class="mt-8">
              <.label>Materials</.label>

              <div
                :if={Enum.empty?(@product.recipe.recipe_materials)}
                class="last:block hidden py-4 text-stone-400 text-sm"
              >
                No materials
              </div>

              <.table
                :if={not Enum.empty?(@product.recipe.recipe_materials)}
                id="recipe"
                rows={@product.recipe.recipe_materials || []}
              >
                <:col :let={pm} label="Material">{pm.material.name}</:col>
                <:col :let={pm} label="Quantity">
                  {pm.quantity} {pm.material.unit}
                </:col>
                <:col :let={pm} label="Cost">
                  {Money.from_float!(
                    :USD,
                    Decimal.to_float(Decimal.mult(pm.quantity, pm.material.price))
                  )}
                </:col>
              </.table>
            </div>
          </div>
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/products/#{@product.id}")}
    >
      <.live_component
        module={MicrocraftWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        product={@product}
        patch={~p"/backoffice/products/#{@product.id}?page=details"}
      />
    </.modal>

    <.modal id="product-material-modal" on_cancel={hide_modal("product-material-modal")}>
      <.live_component
        module={MicrocraftWeb.ProductLive.FormComponentRecipe}
        id="material-form"
        product={@product}
        recipe={@product.recipe || nil}
        current_user={@current_user}
        materials={@materials_available}
        patch={~p"/backoffice/products/#{@product.id}?page=recipe"}
        on_cancel={hide_modal("product-material-modal")}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page: "details",
       materials_available: list_available_materials()
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    product =
      Microcraft.Catalog.get_product_by_id!(id,
        load: [:profit_margin, :estimated_cost, recipe: [recipe_materials: [:material]]]
      )

    page = Map.get(params, "page", "details")

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:product, product)
      |> assign(:status_form, to_form(%{"status" => product.status}))
      |> assign(:page, page)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {MicrocraftWeb.ProductLive.FormComponentRecipe, {:saved, _}},
        socket
      ) do
    product =
      Microcraft.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [:profit_margin, :estimated_cost, recipe: [recipe_materials: [:material]]]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Recipe updated successfully")
     |> assign(:product, product)
     |> push_event("close-modal", %{id: "product-material-modal"})}
  end

  def handle_info(
        {MicrocraftWeb.ProductLive.FormComponent, {:saved, _}},
        socket
      ) do
    product =
      Microcraft.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [:profit_margin, :estimated_cost, recipe: [recipe_materials: [:material]]]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Product updated successfully")
     |> assign(:product, product)}
  end

  @impl true
  def handle_event(
        "product-status-change",
        %{"_target" => ["status"], "status" => status},
        socket
      ) do
    case Ash.update(socket.assigns.product, %{status: status}) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> assign(:product, product)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp page_title(:show), do: "Show Product"
  defp page_title(:edit), do: "Edit Product"

  defp list_available_materials do
    Inventory.list_materials!()
  end
end
