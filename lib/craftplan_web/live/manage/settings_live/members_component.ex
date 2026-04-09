defmodule CraftplanWeb.SettingsLive.MembersComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Accounts

  @role_colors [
    admin: "bg-purple-100 text-purple-700 border-purple-300",
    staff: "bg-blue-100 text-blue-700 border-blue-300",
    customer: "bg-stone-100 text-stone-700 border-stone-300"
  ]

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_invite_modal, fn -> false end)
      |> assign_new(:show_edit_modal, fn -> false end)
      |> assign_new(:editing_member, fn -> nil end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Manage team members and their access roles.
        </:subtitle>
        Members
        <:actions>
          <.button type="button" variant={:primary} phx-click="show_invite_modal" phx-target={@myself}>
            <.icon name="hero-plus" class="mr-2 -ml-1 h-4 w-4" /> Invite Member
          </.button>
        </:actions>
      </.header>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="p-4">
          <.table id="members" rows={@members} wrapper_class="mt-0">
            <:col :let={member} label="Email">{member.email}</:col>
            <:col :let={member} label="Role">
              <.badge text={member.role} colors={role_colors()} />
            </:col>
            <:col :let={member} label="Status">
              <span
                :if={member.confirmed_at}
                class="ring-green-600/20 inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset"
              >
                Active
              </span>
              <span
                :if={is_nil(member.confirmed_at)}
                class="ring-yellow-600/20 inline-flex items-center rounded-full bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-700 ring-1 ring-inset"
              >
                Pending
              </span>
            </:col>
            <:col :let={member} label="Joined">
              {if Map.get(member, :confirmed_at),
                do: Calendar.strftime(member.confirmed_at, "%Y-%m-%d"),
                else: "—"}
            </:col>
            <:action :let={member}>
              <.button
                :if={member.id != @current_user.id}
                size={:sm}
                variant={:secondary}
                phx-click={JS.push("show_edit_modal", value: %{id: member.id}, target: @myself)}
              >
                Edit
              </.button>
              <.button
                :if={member.id != @current_user.id}
                size={:sm}
                variant={:danger}
                phx-click={JS.push("remove_member", value: %{id: member.id}, target: @myself)}
                data-confirm="Are you sure you want to remove this member? This action cannot be undone."
              >
                Remove
              </.button>
            </:action>
            <:empty>
              <div class="py-6 text-center text-sm text-stone-500">
                No team members yet. Invite one using the button above.
              </div>
            </:empty>
          </.table>
        </div>
      </div>

      <.modal
        :if={@show_invite_modal}
        id="invite-member-modal"
        show
        title="Invite Member"
        description="Send an invitation to a new team member"
        on_cancel={JS.push("hide_invite_modal", target: @myself)}
      >
        <.simple_form
          for={@invite_form}
          id="invite-member-form"
          phx-target={@myself}
          phx-change="validate_invite"
          phx-submit="invite_member"
        >
          <.input
            field={@invite_form[:email]}
            type="email"
            label="Email"
            placeholder="member@example.com"
          />
          <.input
            field={@invite_form[:role]}
            type="radiogroup"
            label="Role"
            options={[{"Staff", :staff}, {"Admin", :admin}]}
            value={@invite_form[:role].value || :staff}
          />

          <:actions>
            <.button variant={:primary} phx-disable-with="Sending...">Send Invite</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@show_edit_modal}
        id="edit-role-modal"
        show
        title="Edit Role"
        description={"Change role for #{@editing_member && @editing_member.email}"}
        on_cancel={JS.push("hide_edit_modal", target: @myself)}
      >
        <.simple_form
          for={@role_form}
          id="edit-role-form"
          phx-target={@myself}
          phx-change="validate_role"
          phx-submit="update_role"
        >
          <.input
            field={@role_form[:role]}
            type="radiogroup"
            label="Role"
            options={[{"Staff", :staff}, {"Admin", :admin}]}
            value={@role_form[:role].value}
          />

          <:actions>
            <.button variant={:primary} phx-disable-with="Updating...">Update Role</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    members = load_members(assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:members, members)
     |> assign(:show_invite_modal, false)
     |> assign(:show_edit_modal, false)
     |> assign(:editing_member, nil)
     |> assign(:invite_form, invite_form())
     |> assign(:role_form, role_form(:staff))}
  end

  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: false, invite_form: invite_form())}
  end

  @impl true
  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:editing_member, member)
     |> assign(:role_form, role_form(member.role))}
  end

  @impl true
  def handle_event("hide_edit_modal", _, socket) do
    {:noreply, assign(socket, show_edit_modal: false, editing_member: nil)}
  end

  @impl true
  def handle_event("validate_invite", %{"invite" => params}, socket) do
    {:noreply, assign(socket, :invite_form, invite_form(params))}
  end

  @impl true
  def handle_event("validate_role", %{"role_edit" => params}, socket) do
    {:noreply, assign(socket, :role_form, role_form(params["role"]))}
  end

  @impl true
  def handle_event("invite_member", %{"invite" => params}, socket) do
    invite_params = %{
      email: params["email"],
      role: params["role"] || "staff"
    }

    case Accounts.invite_member(invite_params, actor: socket.assigns.current_user) do
      {:ok, _user} ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:show_invite_modal, false)
         |> assign(:invite_form, invite_form())
         |> put_flash(:info, "Member invited successfully")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to invite member. The email may already be in use.")}
    end
  end

  @impl true
  def handle_event("update_role", %{"role_edit" => params}, socket) do
    member = socket.assigns.editing_member

    case Accounts.update_user_role(member, %{role: params["role"]}, actor: socket.assigns.current_user) do
      {:ok, _updated} ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:show_edit_modal, false)
         |> assign(:editing_member, nil)
         |> put_flash(:info, "Role updated successfully")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    case Accounts.remove_member(member, actor: socket.assigns.current_user) do
      :ok ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Member removed successfully")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end

  defp load_members(user) do
    Accounts.list_members!(actor: user)
  end

  defp invite_form(params \\ %{}) do
    to_form(Map.merge(%{"email" => "", "role" => "staff"}, params), as: "invite")
  end

  defp role_form(role) do
    to_form(%{"role" => to_string(role)}, as: "role_edit")
  end

  defp role_colors, do: @role_colors
end
