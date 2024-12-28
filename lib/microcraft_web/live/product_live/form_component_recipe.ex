defmodule MicrocraftWeb.ProductLive.FormComponentRecipe do
  use MicrocraftWeb, :live_component
  alias AshPhoenix.Form
  alias Microcraft.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="recipe-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          class="field-sizing-content"
          field={@form[:instructions]}
          type="textarea"
          label="Instructions"
        />

        <div>
          <.label>Materials</.label>
          <div
            id="recipe"
            class="w-full mt-2 grid grid-cols-3 gap-x-4 text-sm leading-6 text-stone-700"
          >
            <div
              role="row"
              class="col-span-3 grid grid-cols-3 text-sm text-left leading-6 text-stone-500 border-b border-stone-300"
            >
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 ">
                Name
              </div>
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4">
                Quantity
              </div>
              <div class="p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4">
                <span class="opacity-0">Actions</span>
              </div>
            </div>

            <div role="row" class="col-span-3 last:block hidden py-4 text-stone-400">
              <div class="">
                No materials
              </div>
            </div>

            <.inputs_for :let={recipe_materials_form} field={@form[:recipe_materials]}>
              <div role="row" class="col-span-3 grid grid-cols-3 group hover:bg-stone-200/40">
                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 ">
                  <div class="block py-4 pr-6">
                    <span class="relative">
                      {@materials_map[recipe_materials_form[:material_id].value].name}
                      <.input
                        field={recipe_materials_form[:material_id]}
                        value={recipe_materials_form[:material_id].value}
                        type="hidden"
                      />
                    </span>
                  </div>
                </div>

                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                  <div class="block py-4 pr-6">
                    <span class="relative -mt-2">
                      <div class="border-dashed border-b border-stone-300">
                        <.input
                          flat={true}
                          field={recipe_materials_form[:quantity]}
                          type="number"
                          min="0"
                          inline_label={get_material_unit(@materials_map, recipe_materials_form)}
                        />
                      </div>
                    </span>
                  </div>
                </div>

                <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                  <div class="block py-4 pr-6">
                    <.link
                      class="font-semibold leading-6 text-stone-900 hover:text-stone-700"
                      type="button"
                      phx-click="remove_form"
                      phx-target={@myself}
                      phx-value-path={recipe_materials_form.name}
                    >
                      Remove
                    </.link>
                  </div>
                </div>
              </div>
            </.inputs_for>

            <div
              :if={not Enum.empty?(@available_materials)}
              role="row"
              class="col-span-3 grid grid-cols-3 group hover:bg-stone-200/40"
            >
              <div class="relative p-0 col-span-2 border-r border-stone-200 border-b last:border-r-0 ">
                <span class="relative">
                  <div class="block py-4 pr-6">
                    <div class="border-dashed border-b border-stone-300">
                      <.input
                        phx-change="selected-material-change"
                        name="material_id"
                        type="select"
                        flat={true}
                        value={@selected_material}
                        options={Enum.map(@available_materials, &{&1.name, &1.id})}
                      />
                    </div>
                  </div>
                </span>
              </div>

              <div class="relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4">
                <div class="block py-4 pr-6">
                  <.link
                    class="font-semibold leading-6 text-stone-900 hover:text-stone-700"
                    type="button"
                    phx-click="add_form"
                    phx-target={@myself}
                    phx-value-path={@form[:recipe_materials].name}
                  >
                    Add
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save Recipe</.button>
        </:actions>

        <.input field={@form[:product_id]} type="hidden" value={@product.id} />
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = assign_form(socket)

    materials_map =
      assigns.materials
      |> Enum.map(fn m -> {m.id, m} end)
      |> Map.new()

    {available_materials, selected_material} =
      recompute_availability(socket.assigns.form, assigns.materials)

    {:ok,
     socket
     |> assign(:changed, false)
     |> assign(:materials_map, materials_map)
     |> assign(:available_materials, available_materials)
     |> assign(:selected_material, selected_material)}
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
  def handle_event("selected-material-change", %{"material_id" => material_id}, socket) do
    {:noreply, assign(socket, :selected_material, material_id)}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form =
      AshPhoenix.Form.add_form(socket.assigns.form, path,
        params: %{material_id: socket.assigns.selected_material, quantity: 0}
      )

    {available_materials, selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)
     |> assign(:selected_material, selected_material)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)

    {available_materials, selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)
     |> assign(:selected_material, selected_material)}
  end

  defp assign_form(%{assigns: %{recipe: recipe}} = socket) do
    form =
      if recipe do
        AshPhoenix.Form.for_update(recipe, :update,
          as: "recipe",
          actor: socket.assigns.current_user,
          forms: [
            recipe_materials: [
              type: :list,
              data: recipe.recipe_materials,
              resource: Catalog.RecipeMaterial,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        AshPhoenix.Form.for_create(Catalog.Recipe, :create,
          as: "recipe",
          actor: socket.assigns.current_user,
          forms: [
            recipe_materials: [
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

  defp get_material_unit(materials_map, recipe_materials_form) do
    case Map.get(materials_map, recipe_materials_form[:material_id].value) do
      nil -> ""
      material -> material.unit
    end
  end

  defp recompute_availability(form, all_materials) do
    existing_material_ids =
      form.source.forms.recipe_materials
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
