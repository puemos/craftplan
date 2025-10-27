defmodule CraftplanWeb.CustomerLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias CraftplanWeb.Navigation
  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Customers
      <:subtitle>Manage your customer records</:subtitle>
    </.header>

    <.table
      id="customers"
      rows={@streams.customers}
      row_click={fn {_id, customer} -> JS.navigate(~p"/manage/customers/#{customer.reference}") end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No customers found
          </span>
        </div>
      </:empty>
      <:col :let={{_id, customer}} label="Name">{customer.full_name}</:col>
      <:col :let={{_id, customer}} label="Reference">
        <.kbd>
          {format_reference(customer.reference)}
        </.kbd>
      </:col>
      <:col :let={{_id, customer}} label="Email">{customer.email}</:col>
      <:col :let={{_id, customer}} label="Phone">{customer.phone}</:col>
      <:col :let={{_id, customer}} label="Type">
        <.badge text={customer.type} />
      </:col>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="customer-modal"
      title={@page_title}
      description="Use this form to manage customer records in your database."
      show
      on_cancel={JS.patch(~p"/manage/customers")}
    >
      <.live_component
        module={CraftplanWeb.CustomerLive.FormComponent}
        id={(@customer && @customer.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        customer={@customer}
        settings={@settings}
        patch={~p"/manage/customers"}
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
       Ash.read!(Craftplan.CRM.Customer,
         actor: socket.assigns[:current_user],
         load: [:billing_address, :shipping_address, :full_name]
       )
     )
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    {:noreply, Navigation.assign(socket, :customers, customer_index_trail(socket.assigns))}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(
      :customer,
      Craftplan.CRM.get_customer_by_id!(id,
        actor: socket.assigns.current_user,
        load: [:billing_address, :shipping_address]
      )
    )
  end

  defp apply_action(socket, :edit, %{"reference" => reference}) do
    socket
    |> assign(:page_title, "Edit Customer")
    |> assign(
      :customer,
      Craftplan.CRM.get_customer_by_reference!(reference,
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

  defp customer_index_trail(%{live_action: :new}),
    do: [Navigation.root(:customers), Navigation.page(:customers, :new_customer)]

  defp customer_index_trail(%{live_action: :edit, customer: %{} = customer}),
    do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]

  defp customer_index_trail(_), do: [Navigation.root(:customers)]

  @impl true
  def handle_info({{CraftplanWeb.CustomerLive.FormComponent, :saved, customer}}, socket) do
    {:noreply, stream_insert(socket, :customers, customer)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Material |> Ash.get!(id) |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Customer deleted successfully")
         |> stream_delete(:customers, id)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete material.")}
    end
  end
end
