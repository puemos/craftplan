defmodule MicrocraftWeb.CustomerLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Manage your customers
      <:subtitle>
        <.breadcrumb>
          <:crumb label="All Customers" path={~p"/backoffice/customers"} current?={true} />
        </.breadcrumb>
      </:subtitle>
      <:actions>
        <.link patch={~p"/backoffice/customers/new"}>
          <.button>New Customer</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="customers"
      rows={@streams.customers}
      row_click={fn {_id, customer} -> JS.navigate(~p"/backoffice/customers/#{customer.id}") end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No customers found
          </span>
        </div>
      </:empty>
      <:col :let={{_id, customer}} label="Name">{customer.full_name}</:col>
      <:col :let={{_id, customer}} label="Email">{customer.email}</:col>
      <:col :let={{_id, customer}} label="Phone">{customer.phone}</:col>
      <:col :let={{_id, customer}} label="Type">
        <.badge text={customer.type} />
      </:col>

      <:action :let={{_id, customer}}>
        <.link patch={~p"/backoffice/customers/#{customer.id}/edit"}>Edit</.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="customer-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/customers")}
    >
      <.live_component
        module={MicrocraftWeb.CustomerLive.FormComponent}
        id={(@customer && @customer.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        customer={@customer}
        patch={~p"/backoffice/customers"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(
       :customers,
       Ash.read!(Microcraft.CRM.Customer,
         actor: socket.assigns[:current_user],
         load: [:billing_address, :shipping_address, :full_name]
       )
     )
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(
      :customer,
      Microcraft.CRM.get_customer_by_id!(id,
        actor: socket.assigns.current_user,
        load: [:billing_address, :shipping_address]
      )
    )
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Customer")
    |> assign(:customer, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Customers")
    |> assign(:customer, nil)
  end

  @impl true
  def handle_info({:saved, customer}, socket) do
    {:noreply, stream_insert(socket, :customers, customer)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Material |> Ash.get!(id) |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted successfully")
         |> stream_delete(:materials, id)}

      {:error, _error} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete material.")}
    end
  end
end
