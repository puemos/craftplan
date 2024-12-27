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
        <.input field={@form[:product_id]} type="hidden" value={@product.id} />
        <.input field={@form[:instructions]} type="textarea" label="Instructions" />
        <div>
          <.label>Materials</.label>
          <div
            id="recipe"
            class="w-full mt-2 table-auto table relative divide-y divide-stone-200 text-sm leading-6 text-stone-700"
          >
            <div
              role="row"
              class="table-header-group w-full text-sm text-left leading-6 text-stone-500 border-b border-stone-300"
            >
              <div role="row" class="table-row w-full">
                <div
                  role="cell"
                  class="table-cell p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 border-b border-stone-300"
                >
                  Name
                </div>
                <div
                  role="cell"
                  class="table-cell p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0 pl-4 border-b border-stone-300"
                >
                  Quantity
                </div>

                <div
                  role="cell"
                  class="relative p-0 pb-4 pr-4 border-r border-stone-200 last:border-r-0 border-b border-stone-300"
                >
                  <span class="opacity-0">Actions</span>
                </div>
              </div>
            </div>

            <div class="table-row-group">
              <div class="last:block hidden py-4 text-stone-400">
                No materials
              </div>
              <.inputs_for :let={recipe_materials_form} field={@form[:recipe_materials]}>
                <div role="row" class="w-full group hover:bg-stone-200/40 table-row">
                  <div
                    role="cell"
                    class="table-cell relative p-0 border-r border-stone-200 border-b last:border-r-0 "
                  >
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        <.input
                          field={recipe_materials_form[:material_id]}
                          type="select"
                          options={Enum.map(@materials, &{&1.name, &1.id})}
                        />
                      </span>
                    </div>
                  </div>
                  <div
                    role="cell"
                    class="table-cell relative p-0 border-r border-stone-200 border-b last:border-r-0 pl-4"
                  >
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        <.input field={recipe_materials_form[:quantity]} type="number" />
                      </span>
                    </div>
                  </div>

                  <div
                    role="cell"
                    class="table-cell relative w-14 p-0 pr-4 border-r border-stone-200 border-b last:border-r-0 "
                  >
                    <.link
                      class="relative ml-4 font-semibold leading-6 text-stone-900 hover:text-stone-700"
                      type="button"
                      phx-click="remove_form"
                      phx-target={@myself}
                      phx-value-path={recipe_materials_form.name}
                    >
                      Remove
                    </.link>
                  </div>
                </div>
              </.inputs_for>
            </div>
          </div>
        </div>

        <:actions>
          <.button
            type="button"
            phx-click="add_form"
            phx-target={@myself}
            phx-value-path={@form[:recipe_materials].name}
          >
            Add material
          </.button>
          <.button phx-disable-with="Saving...">Save Recipe</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, recipe_params))}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    case Form.submit(socket.assigns.form, params: recipe_params) do
      {:ok, recipe} ->
        send(self(), {__MODULE__, {:saved, recipe}})

        {:noreply,
         socket
         |> put_flash(:info, "Material #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("add_form", %{"path" => path}, socket) do
    in_place =
      MapSet.new(socket.assigns.form.data.recipe_materials, fn recipe_material ->
        recipe_material.material_id
      end)

    all =
      MapSet.new(socket.assigns.materials, fn material ->
        material.id
      end)

    diff = MapSet.difference(all, in_place)

    if MapSet.size(diff) == 0 do
      {:noreply, socket}
    else
      material_id = MapSet.to_list(diff) |> List.first()

      form =
        AshPhoenix.Form.add_form(socket.assigns.form, path,
          params: %{material_id: material_id, quantity: 0}
        )

      {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, form: form)}
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

    assign(socket, form: to_form(form))
  end
end
