defmodule MicrocraftWeb.InventoryLive.FormComponentNutritionalFacts do
  @moduledoc false
  use MicrocraftWeb, :live_component

  alias AshPhoenix.Form
  alias Microcraft.Inventory.MaterialNutritionalFact

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="material-nutritional-facts-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:material_id]} type="hidden" value={@material.id} />

          <h3 class="text-lg font-medium">Nutritional Facts</h3>
          <p class="mb-4 text-sm text-stone-500">Add nutritional facts for this material</p>

          <div id="nutritional-facts-list">
            <div
              id="nutritional-facts"
              class="mt-2 grid w-full grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
            >
              <div
                role="row"
                class="col-span-4 grid grid-cols-4 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
              >
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0 ">
                  Fact
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  Amount
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  Unit
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  <span class="opacity-0">Actions</span>
                </div>
              </div>

              <div role="row" class="col-span-4 hidden py-4 text-stone-400 last:block">
                <div class="">
                  No nutritional facts
                </div>
              </div>

              <.inputs_for :let={fact_form} field={@form[:material_nutritional_facts]}>
                <div role="row" class="group col-span-4 grid grid-cols-4 hover:bg-stone-200/40">
                  <div class="relative border-r border-b border-stone-200 p-0 last:border-r-0 ">
                    <div class="block py-4 pr-6">
                      <span class="relative -mt-2">
                        <.input
                          field={fact_form[:nutritional_fact_id]}
                          type="select"
                          options={nutritional_fact_options(@nutritional_facts)}
                          flat={true}
                        />
                        <.input field={fact_form[:material_id]} type="hidden" value={@material.id} />
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative -mt-2">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            field={fact_form[:amount]}
                            type="number"
                            step="0.01"
                            min="0"
                            flat={true}
                          />
                        </div>
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative -mt-2">
                        <.input
                          field={fact_form[:unit]}
                          type="select"
                          options={[
                            {"Gram", :gram},
                            {"Milliliter", :milliliter},
                            {"Piece", :piece}
                          ]}
                          flat={true}
                        />
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <label class="cursor-pointer">
                        <input
                          type="checkbox"
                          name={"#{@form.name}[_drop_material_nutritional_facts][]"}
                          value={fact_form.index}
                          class="hidden"
                        />
                        <span class="p-1 text-rose-500 hover:text-rose-700">
                          <.icon name="hero-trash" class="h-5 w-5" />
                        </span>
                      </label>
                    </div>
                  </div>
                </div>
              </.inputs_for>

              <div role="row" class="col-span-4 py-4">
                <label class="inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50">
                  <input
                    type="checkbox"
                    name={"#{@form.name}[_add_material_nutritional_facts]"}
                    value="end"
                    class="hidden"
                  />
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Nutritional Fact
                </label>
              </div>
            </div>
          </div>
        </div>

        <:actions>
          <.button type="submit" phx-disable-with="Saving...">
            Save Nutritional Facts
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{material: material} = assigns, socket) do
    form = build_form(material, assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"material" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"material" => params}, socket) do
    IO.inspect(params, label: "Save Parameters")

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, result} ->
        IO.inspect(result, label: "Save Result")

        send(self(), {:saved_nutritional_facts, socket.assigns.material.id})

        {:noreply,
         socket
         |> put_flash(:info, "Nutritional facts updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} = error ->
        IO.inspect(error, label: "Save Error")

        {:noreply, assign(socket, :form, form)}
    end
  end

  defp build_form(material, actor) do
    material_with_nutritional_facts =
      Ash.load!(material, [
        :nutritional_facts,
        material_nutritional_facts: [:nutritional_fact]
      ])

    IO.inspect(material_with_nutritional_facts.material_nutritional_facts,
      label: "Loaded Nutritional Facts"
    )

    material_with_nutritional_facts
    |> AshPhoenix.Form.for_update(:update_nutritional_facts,
      actor: actor,
      as: "material",
      forms: [
        material_nutritional_facts: [
          # Using :list as specified instead of :array
          type: :list,
          resource: MaterialNutritionalFact,
          data: material_with_nutritional_facts.material_nutritional_facts,
          create_action: :create,
          update_action: :update
        ]
      ]
    )
    |> to_form()
  end

  defp nutritional_fact_options(facts) do
    Enum.map(facts, fn fact -> {fact.name, fact.id} end)
  end

  defp get_fact_name(fact_id, facts) do
    facts
    |> Enum.find(fn fact -> fact.id == fact_id end)
    |> case do
      nil -> "New Nutritional Fact"
      fact -> fact.name
    end
  end
end
