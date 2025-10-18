defmodule CraftplanWeb.SettingsLive.AllergensComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Allergen

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div>
      <.header>
        <:subtitle>Manage allergens for all products and materials</:subtitle>
        Allergens
        <:actions>
          <button
            type="button"
            phx-click="show_add_modal"
            phx-target={@myself}
            class="inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Allergen
          </button>
        </:actions>
      </.header>

      <div class="mt-6">
        <.table id="allergens" rows={@allergens}>
          <:col :let={allergen} label="Name">{allergen.name}</:col>
          <:action :let={allergen}>
            <.link
              phx-click={JS.push("delete", value: %{id: allergen.id}, target: @myself)}
              data-confirm="Are you sure you want to delete this allergen? This action cannot be undone."
            >
              <.button size={:sm} variant={:danger}>
                Delete
              </.button>
            </.link>
          </:action>
        </.table>
      </div>

      <.modal
        :if={@show_modal}
        id="add-allergen-modal"
        show
        title="Add New Allergen"
        description="Enter the name of the allergen you want to add"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="allergen-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Allergen name" />
          <:actions>
            <.button phx-disable-with="Saving...">Save Allergen</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    allergens = Inventory.list_allergens!()
    form = new_allergen_form(assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:allergens, allergens)
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"allergen" => allergen_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, allergen_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"allergen" => allergen_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: allergen_params) do
      {:ok, _allergen} ->
        # Notify parent to reload allergens
        send(self(), {:saved_allergens, nil})

        allergens = Inventory.list_allergens!()

        {:noreply,
         socket
         |> assign(:allergens, allergens)
         |> assign(:form, new_allergen_form(socket.assigns.current_user))
         |> assign(:show_modal, false)
         |> put_flash(:info, "Allergen added successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    allergen = Inventory.get_allergen_by_id!(id)
    :ok = Ash.destroy!(allergen, actor: socket.assigns.current_user)

    # Notify parent to reload allergens
    send(self(), {:saved_allergens, nil})

    allergens = Inventory.list_allergens!()

    {:noreply,
     socket
     |> assign(:allergens, allergens)
     |> put_flash(:info, "Allergen deleted successfully")}
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  defp new_allergen_form(user) do
    Allergen
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "allergen"
    )
    |> to_form()
  end
end
