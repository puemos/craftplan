defmodule CraftplanWeb.ProductLive.FormComponentRecipe do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Catalog

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="recipe-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:product_id]} type="hidden" value={@product.id} />

          <h3 class="text-lg font-medium">Recipe</h3>
          <p class="mb-4 text-sm text-stone-500">Add materials needed for this product</p>

          <div id="recipe-materials-list">
            <div
              id="recipe"
              class="mt-2 grid w-full grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
            >
              <div
                role="row"
                class="col-span-4 grid grid-cols-4 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
              >
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0 ">
                  Material
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  Quantity
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  Total Cost
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  <span class="opacity-0">Actions</span>
                </div>
              </div>

              <div role="row" class="col-span-4 hidden py-4 text-stone-400 last:block">
                <div class="">
                  No materials in recipe
                </div>
              </div>

              <.inputs_for :let={components_form} field={@form[:components]}>
                <div role="row" class="group col-span-4 grid grid-cols-4 hover:bg-stone-200/40">
                  <div class="relative border-r border-b border-stone-200 p-0 last:border-r-0 ">
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        <.link
                          navigate={
                            ~p"/manage/inventory/#{@materials_map[components_form[:material_id].value].sku}"
                          }
                          class="hover:text-blue-800 hover:underline"
                        >
                          {@materials_map[components_form[:material_id].value].name}
                        </.link>
                        <.input
                          field={components_form[:material_id]}
                          value={components_form[:material_id].value}
                          type="hidden"
                        />
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative -mt-2">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={components_form[:quantity]}
                            type="number"
                            min="0"
                            step="0.01"
                            inline_label={get_material_unit(@materials_map, components_form)}
                          />
                        </div>
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        {format_money(
                          @settings.currency,
                          Decimal.mult(
                            @materials_map[components_form[:material_id].value].price || 0,
                            components_form[:quantity].value || 0
                          )
                        )}
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <label class="cursor-pointer">
                        <input
                          type="checkbox"
                          phx-click="remove_form"
                          phx-target={@myself}
                          phx-value-path={components_form.name}
                          class="hidden"
                        />
                        <span class="font-semibold leading-6 text-stone-900 hover:text-stone-700">
                          Remove
                        </span>
                      </label>
                    </div>
                  </div>
                </div>
              </.inputs_for>

              <div role="row" class="col-span-4 py-4">
                <button
                  type="button"
                  phx-click="show_add_modal"
                  phx-target={@myself}
                  class={[
                    "inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50",
                    Enum.empty?(@available_materials) && "cursor-not-allowed opacity-50"
                  ]}
                  disabled={Enum.empty?(@available_materials)}
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Material
                </button>
              </div>
            </div>
          </div>

          <.input
            class="field-sizing-content mt-6"
            field={@form[:notes]}
            type="textarea"
            label="Notes"
          />
        </div>

        <:actions>
          <.button
            variant={:primary}
            type="submit"
            disabled={not @form.source.changed? || not @form.source.valid?}
            phx-disable-with="Saving..."
          >
            Save Recipe
          </.button>
        </:actions>
      </.simple_form>

      <%= if @show_modal do %>
        <.modal
          title="Select a material to add to the recipe:"
          id="add-recipe-material-modal"
          show
          on_cancel={JS.push("hide_modal", target: @myself)}
        >
          <div class="mt-4 space-y-6">
            <div class="max-h-64 overflow-y-auto">
              <ul class="divide-y divide-stone-200">
                <%= for material <- @available_materials do %>
                  <li>
                    <button
                      type="button"
                      phx-click="add_material"
                      phx-value-material-id={material.id}
                      phx-target={@myself}
                      class="w-full rounded-md px-3 py-2 text-left transition duration-150 ease-in-out hover:bg-stone-100"
                    >
                      {material.name}
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <.button phx-click="hide_modal" phx-target={@myself} class="mt-5">Cancel</.button>
        </.modal>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = assign_form(socket)

    materials_map =
      Map.new(assigns.materials, fn m -> {m.id, m} end)

    {available_materials, _selected_material} =
      recompute_availability(socket.assigns.form, assigns.materials)

    {:ok,
     socket
     |> assign(:changed, false)
     |> assign(:materials_map, materials_map)
     |> assign(:available_materials, available_materials)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    form = Form.validate(socket.assigns.form, recipe_params)
    {:noreply, assign(socket, form: form, changed: true)}
  end

  @impl true
  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    case Form.submit(socket.assigns.form, params: recipe_params) do
      {:ok, recipe} ->
        send(self(), {__MODULE__, {:saved, recipe}})

        {:noreply,
         socket
         |> put_flash(:info, "Recipe saved successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    # Only show the modal if there are materials to add
    if Enum.empty?(socket.assigns.available_materials) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_modal, true)}
    end
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("add_material", %{"material-id" => material_id}, socket) do
    # Add a new component form with the selected material
    form =
      Form.add_form(socket.assigns.form, socket.assigns.form[:components].name,
        params: %{material_id: material_id, quantity: 0}
      )

    # Recompute available materials after adding this one
    {available_materials, _selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = Form.remove_form(socket.assigns.form, path)

    {available_materials, _selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)}
  end

  defp assign_form(%{assigns: %{recipe: recipe}} = socket) do
    form =
      if recipe do
        Form.for_update(recipe, :update,
          as: "recipe",
          actor: socket.assigns.current_user,
          forms: [
            components: [
              type: :list,
              data: recipe.components,
              resource: Catalog.RecipeMaterial,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        Form.for_create(Catalog.Recipe, :create,
          as: "recipe",
          actor: socket.assigns.current_user,
          forms: [
            components: [
              type: :list,
              resource: Catalog.RecipeMaterial,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    assign(socket, :form, to_form(form))
  end

  defp get_material_unit(materials_map, components_form) do
    case Map.get(materials_map, components_form[:material_id].value) do
      nil -> ""
      material -> material.unit
    end
  end

  defp recompute_availability(form, all_materials) do
    existing_material_ids =
      (form.source.forms[:components] || [])
      |> Enum.map(fn recipe_mat_form ->
        recipe_mat_form.params[:material_id] ||
          (recipe_mat_form.data && recipe_mat_form.data.material_id)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    available_materials =
      Enum.reject(all_materials, fn m -> m.id in existing_material_ids end)

    selected_material =
      case available_materials do
        [first | _] -> first.id
        [] -> nil
      end

    {available_materials, selected_material}
  end
end
