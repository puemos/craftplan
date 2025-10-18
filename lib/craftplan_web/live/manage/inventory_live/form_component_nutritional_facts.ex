defmodule CraftplanWeb.InventoryLive.FormComponentNutritionalFacts do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Inventory.MaterialNutritionalFact

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

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
                    Enum.empty?(
                      available_nutritional_fact_options(@nutritional_facts, @form, @existing_facts)
                    ) && "cursor-not-allowed opacity-50"
                  ]}
                  disabled={
                    Enum.empty?(
                      available_nutritional_fact_options(@nutritional_facts, @form, @existing_facts)
                    )
                  }
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Nutritional Fact
                </button>
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

      <%= if @show_modal do %>
        <.modal
          id="add-nutritional-fact-modal"
          show
          title="Select a nutritional fact to add:"
          on_cancel={JS.push("hide_modal", target: @myself)}
        >
          <div class="mt-4 space-y-6">
            <div class="max-h-64 overflow-y-auto">
              <ul class="divide-y divide-stone-200">
                <%= for {name, id} <- available_nutritional_fact_options(@nutritional_facts, @form, @existing_facts) do %>
                  <li>
                    <button
                      type="button"
                      phx-click="add_nutritional_fact"
                      phx-value-fact-id={id}
                      phx-target={@myself}
                      class="w-full rounded-md px-3 py-2 text-left transition duration-150 ease-in-out hover:bg-stone-100"
                    >
                      {name}
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
  def update(%{material: material} = assigns, socket) do
    form = build_form(material, assigns.current_user)

    # Store the existing facts as a separate attribute for recovery if needed
    existing_facts =
      Enum.map(material.material_nutritional_facts, fn fact ->
        %{
          "nutritional_fact_id" => fact.nutritional_fact_id,
          "material_id" => fact.material_id,
          "amount" => fact.amount,
          "unit" => fact.unit
        }
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:existing_facts, existing_facts)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"material" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    # Only show the modal if there are facts to add
    if Enum.empty?(
         available_nutritional_fact_options(
           socket.assigns.nutritional_facts,
           socket.assigns.form,
           socket.assigns.existing_facts
         )
       ) do
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
  def handle_event("add_nutritional_fact", %{"fact-id" => fact_id}, socket) do
    # Get the current form and existing facts
    current_form = socket.assigns.form

    # Get the existing material_nutritional_facts from the form params or from our backup
    existing_facts_data =
      case current_form.source.params do
        %{"material_nutritional_facts" => facts} when is_map(facts) and map_size(facts) > 0 ->
          Map.values(facts)

        %{"material_nutritional_facts" => facts} when is_list(facts) and length(facts) > 0 ->
          facts

        _ ->
          # If the form doesn't have facts yet, use our backup
          socket.assigns.existing_facts || []
      end

    # Create the new fact to add
    new_fact = %{
      "nutritional_fact_id" => fact_id,
      "material_id" => socket.assigns.material.id,
      "amount" => "0",
      # Default unit
      "unit" => "gram"
    }

    # Combine existing facts with the new fact
    updated_facts = existing_facts_data ++ [new_fact]

    # Create a complete set of params including the material ID and updated facts
    updated_params = %{
      "material_id" => socket.assigns.material.id,
      "material_nutritional_facts" => updated_facts
    }

    # Validate with the updated params
    updated_form = Form.validate(current_form, updated_params)

    # Keep track of the current facts for future reference
    updated_existing_facts = updated_facts

    {:noreply,
     socket
     |> assign(:form, updated_form)
     |> assign(:existing_facts, updated_existing_facts)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("save", %{"material" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _result} ->
        send(self(), {:saved_nutritional_facts, socket.assigns.material.id})

        {:noreply,
         socket
         |> put_flash(:info, "Nutritional facts updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp build_form(material, actor) do
    material_with_nutritional_facts =
      Ash.load!(
        material,
        [
          :nutritional_facts,
          material_nutritional_facts: [:nutritional_fact]
        ],
        actor: actor
      )

    material_with_nutritional_facts
    |> Form.for_update(:update_nutritional_facts,
      actor: actor,
      as: "material",
      forms: [
        material_nutritional_facts: [
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

  # Returns all nutritional fact options
  defp nutritional_fact_options(facts) do
    facts
    |> Enum.map(fn fact -> {fact.name, fact.id} end)
    |> Enum.sort_by(fn {name, _id} -> name end)
  end

  # Returns only nutritional facts that haven't been added yet
  defp available_nutritional_fact_options(all_facts, form, backup_facts) do
    # Get already selected fact IDs from the form or from backup
    selected_fact_ids =
      case form.source.params do
        %{"material_nutritional_facts" => facts} when is_map(facts) and map_size(facts) > 0 ->
          facts
          |> Map.values()
          |> Enum.map(fn fact -> fact["nutritional_fact_id"] end)
          |> Enum.filter(& &1)

        %{"material_nutritional_facts" => facts} when is_list(facts) and length(facts) > 0 ->
          facts
          |> Enum.map(fn fact -> fact["nutritional_fact_id"] end)
          |> Enum.filter(& &1)

        _ ->
          # If no facts in the form, use backup facts
          backup_facts
          |> Enum.map(fn fact -> fact["nutritional_fact_id"] end)
          |> Enum.filter(& &1)
      end

    # Filter out already selected facts
    available_facts =
      Enum.filter(all_facts, fn fact ->
        fact.id not in selected_fact_ids
      end)

    # Return options for available facts
    available_facts
    |> Enum.map(fn fact -> {fact.name, fact.id} end)
    |> Enum.sort_by(fn {name, _id} -> name end)
  end
end
