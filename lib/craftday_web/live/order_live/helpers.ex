defmodule CraftdayWeb.OrderLive.Helpers do
  @moduledoc """
  Helper functions specific to the OrderLive module, focused on order-related
  calculations and view transformations.
  """

  import CraftdayWeb.HtmlHelpers

  @doc """
  Check if an order is urgent (due soon)
  """
  def is_urgent_order(order) do
    now = DateTime.utc_now()
    delivery_date = order.delivery_date

    # Calculate days until delivery
    days_until_delivery =
      delivery_date
      |> DateTime.diff(now, :second)
      |> Kernel./(86_400)
      |> Float.round(1)

    # Consider urgent if less than 2 days and not completed/delivered/cancelled
    days_until_delivery <= 2 &&
      order.status not in [:completed, :delivered, :cancelled]
  end

  @doc """
  Create calendar events from orders
  """
  def create_calendar_events(orders, event_duration) do
    Enum.map(orders, fn order ->
      %{
        id: order.reference,
        title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
        start: DateTime.to_iso8601(order.delivery_date),
        end:
          order.delivery_date
          |> DateTime.add(event_duration, :second)
          |> DateTime.to_iso8601(),
        color: get_status_color_hex(order.status),
        textColor: "#000",
        url: nil,
        # Additional separated information for further customization
        extendedProps: %{
          customer: %{
            name: order.customer.full_name,
            reference: order.customer.reference
          },
          order: %{
            reference: order.reference,
            status: order.status,
            payment_status: order.payment_status,
            total_cost: order.total_cost
          }
        }
      }
    end)
  end
end
