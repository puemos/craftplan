defmodule CraftdayWeb.InventoryLive.FormComponentAllergens do
  @moduledoc false
  use CraftdayWeb, :live_component

  alias AshPhoenix.Form

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="material-allergen-form-2"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          type="checkgroup"
          name="allergen_ids[]"
          options={Enum.map(@allergens, fn allergen -> {allergen.name, allergen.id} end)}
          value={@selected_allergen_ids}
        />

        <:actions>
          <.button
            disabled={
              MapSet.equal?(MapSet.new(@init_allergen_ids), MapSet.new(@selected_allergen_ids))
            }
            phx-disable-with="Saving..."
          >
            Save Allergens
          </.button>
        </:actions>

        <.input field={@form[:material_id]} type="hidden" value={@material.id} />
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    allergens_map =
      Map.new(assigns.allergens, fn allergen -> {allergen.id, allergen} end)

    socket =
      socket
      |> assign(assigns)
      |> assign(:allergens_map, allergens_map)

    form = build_form(socket.assigns.material, socket.assigns.current_user)

    selected_allergen_ids = Enum.map(socket.assigns.material.allergens, & &1.id)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:init_allergen_ids, selected_allergen_ids)
     |> assign(:selected_allergen_ids, selected_allergen_ids)}
  end

  @impl true
  def handle_event("validate", %{"material" => params, "allergen_ids" => allergen_ids}, socket) do
    form = Form.validate(socket.assigns.form, params)

    allergen_ids = Enum.filter(allergen_ids, fn id -> id != "" end)

    {:noreply,
     socket
     |> assign(form: form)
     |> assign(:selected_allergen_ids, allergen_ids)}
  end

  def handle_event("save", %{"allergen_ids" => allergen_ids}, socket) do
    params = %{
      "material_allergens" =>
        allergen_ids
        |> Enum.filter(fn id -> id != "" end)
        |> Enum.map(fn id ->
          %{"allergen_id" => id, "material_id" => socket.assigns.material.id}
        end)
    }

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _result} ->
        send(self(), {:saved_allergens, socket.assigns.material.id})

        {:noreply,
         socket
         |> put_flash(:info, "Allergens updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp build_form(material, actor) do
    material_with_allergens = Ash.load!(material, :allergens, actor: actor)

    material_with_allergens
    |> Form.for_update(:update_allergens,
      actor: actor,
      as: "material"
    )
    |> to_form()
  end
end
