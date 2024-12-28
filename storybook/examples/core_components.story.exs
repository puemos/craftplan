defmodule Storybook.Examples.CoreComponents do
  use PhoenixStorybook.Story, :example
  import MicrocraftWeb.CoreComponents

  alias Phoenix.LiveView.JS

  def doc do
    "An example of what you can achieve with Phoenix core components."
  end

  defstruct [:id, :first_name, :last_name]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_id: 2,
       users: [
         %__MODULE__{id: 1, first_name: "Jose", last_name: "Valim"},
         %__MODULE__{
           id: 2,
           first_name: "Chris",
           last_name: "McCord"
         }
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      List of users
      <:subtitle>Feel free to add any missing user!</:subtitle>
      <:actions>
        <.button phx-click={show_modal("new-user-modal")}>Create user</.button>
      </:actions>
    </.header>
    <.table id="user-table" rows={@users}>
      <:col :let={user} label="Id">
        <%= user.id %>
      </:col>
      <:col :let={user} label="First name">
        <%= user.first_name %>
      </:col>
      <:col :let={user} label="Last name">
        <%= user.last_name %>
      </:col>
    </.table>
    <.modal id="new-user-modal">
      <.header>
        Create new user
        <:subtitle>This won't be persisted into DB, memory only</:subtitle>
      </.header>
      <.simple_form
        :let={f}
        for={%{}}
        as={:user}
        phx-submit={JS.push("save_user") |> hide_modal("new-user-modal")}
      >
        <.input field={f[:first_name]} label="First name" />
        <.input field={f[:last_name]} label="Last name" />
        <:actions>
          <.button>Save user</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  @impl true
  def handle_event("save_user", %{"user" => params}, socket) do
    user = %__MODULE__{
      first_name: params["first_name"],
      last_name: params["last_name"],
      id: socket.assigns.current_id + 1
    }

    {:noreply,
     socket
     |> update(:users, &(&1 ++ [user]))
     |> update(:current_id, &(&1 + 1))}
  end
end
