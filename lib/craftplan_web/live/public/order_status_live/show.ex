defmodule CraftplanWeb.Public.OrderStatusLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Order Status" path={~p"/o/#{@reference}"} current?={true} />
      </.breadcrumb>
      <:actions>
        <.button variant={:outline} onclick="window.print()" class="print:hidden">Print</.button>
      </:actions>
    </.header>

    <div class="mx-auto max-w-3xl bg-white p-4 print:m-0 print:max-w-full print:border-0 print:p-0 print:shadow-none">
      <div
        :if={@not_found}
        class="rounded border border-stone-300 bg-white p-6 text-center text-stone-600"
      >
        Order not found. Please check your reference.
      </div>

      <div :if={!@not_found} class="space-y-4">
        <div class="flex items-center justify-between">
          <div>
            <div class="text-sm text-stone-500">Reference</div>
            <div class="font-semibold">
              <.kbd>{@order.reference}</.kbd>
            </div>
          </div>
          <div class="text-right">
            <div class="text-sm text-stone-500">Delivery/Pickup Date</div>
            <div class="font-semibold">
              {DateTime.to_date(@order.delivery_date) |> Date.to_iso8601()}
            </div>
          </div>
        </div>

        <.table id="order-items" no_margin rows={@order.items}>
          <:col :let={item} label="Product">{item.product.name}</:col>
          <:col :let={item} label="Qty" align={:right}>{item.quantity}</:col>
          <:empty>
            <div class="py-6 text-center text-stone-500">No items</div>
          </:empty>
        </.table>

        <div class="mt-4 flex items-center justify-between print:text-sm">
          <div class="text-stone-600">
            Status: <span class="font-medium">{to_string(@order.status) |> String.capitalize()}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"reference" => reference}, _session, socket) do
    order =
      case Orders.public_get_order_by_reference(reference,
             load: [items: [product: [:name, :sku]]]
           ) do
        {:ok, nil} -> nil
        {:ok, order} -> order
      end

    {:ok,
     socket
     |> assign(:reference, reference)
     |> assign(:order, order)
     |> assign(:not_found, is_nil(order))}
  end
end
