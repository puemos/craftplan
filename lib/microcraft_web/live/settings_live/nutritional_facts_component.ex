defmodule MicrocraftWeb.SettingsLive.NutritionalFactsComponent do
  @moduledoc false
  use MicrocraftWeb, :live_component

  alias Microcraft.Inventory
  alias Microcraft.Inventory.NutritionalFact

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div>
      <.header>
        <:subtitle>Manage nutritional facts for all products and materials</:subtitle>
        Nutritional Facts
        <:actions>
          <button
            type="button"
            phx-click="show_modal"
            phx-target={@myself}
            class="inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Nutritional Fact
          </button>
        </:actions>
      </.header>

      <div class="mt-6">
        <.table id="nutritional-facts" rows={@nutritional_facts}>
          <:col :let={fact} label="Name">{fact.name}</:col>
          <:action :let={fact}>
            <.link
              phx-click={JS.push("delete", value: %{id: fact.id}, target: @myself)}
              data-confirm="Are you sure you want to delete this nutritional fact? This action cannot be undone."
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
        id="add-nutritional-fact-modal"
        show
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.header>
          Add Nutritional Fact
          <:subtitle>Enter the name of the nutritional fact you want to add</:subtitle>
        </.header>

        <.simple_form
          for={@form}
          id="nutritional-fact-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Nutritional fact name" />
          <:actions>
            <.button phx-disable-with="Saving...">Add Nutritional Fact</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    nutritional_facts = Inventory.list_nutritional_facts!()
    form = new_nutritional_fact_form(assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:nutritional_facts, nutritional_facts)
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"nutritional_fact" => fact_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, fact_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"nutritional_fact" => fact_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: fact_params) do
      {:ok, _nutritional_fact} ->
        # Notify parent to reload nutritional facts
        send(self(), {:saved_nutritional_facts, nil})

        nutritional_facts = Inventory.list_nutritional_facts!()

        {:noreply,
         socket
         |> assign(:nutritional_facts, nutritional_facts)
         |> assign(:form, new_nutritional_fact_form(socket.assigns.current_user))
         |> assign(:show_modal, false)
         |> put_flash(:info, "Nutritional fact added successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    nutritional_fact = Inventory.get_nutritional_fact_by_id!(id)
    :ok = Ash.destroy!(nutritional_fact, actor: socket.assigns.current_user)

    # Notify parent to reload nutritional facts
    send(self(), {:saved_nutritional_facts, nil})

    nutritional_facts = Inventory.list_nutritional_facts!()

    {:noreply,
     socket
     |> assign(:nutritional_facts, nutritional_facts)
     |> put_flash(:info, "Nutritional fact deleted successfully")}
  end

  @impl true
  def handle_event("show_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  defp new_nutritional_fact_form(user) do
    NutritionalFact
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "nutritional_fact"
    )
    |> to_form()
  end
end
