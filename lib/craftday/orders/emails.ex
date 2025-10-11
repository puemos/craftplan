defmodule Craftday.Orders.Emails do
  @moduledoc """
  Order emails (confirmation, etc.)
  """

  import Swoosh.Email

  alias Craftday.Mailer

  def deliver_order_confirmation(order, opts \\ []) do
    to = order.customer && order.customer.email

    if is_nil(to) do
      {:error, :no_recipient}
    else
      sender = Keyword.get(opts, :from, {"Craftday", "noreply@craftday.app"})

      body = build_body(order)

      new()
      |> from(sender)
      |> to(to)
      |> subject("Your order #{order.reference}")
      |> html_body(body)
      |> Mailer.deliver()
    end
  end

  defp build_body(order) do
    items_html =
      Enum.map_join(order.items || [], "", fn item ->
        "<li>#{item.quantity} × #{item.product.name}</li>"
      end)

    """
    <html>
      <p>Thank you for your order!</p>
      <p>Reference: <strong>#{order.reference}</strong></p>
      <p>Delivery: #{order.delivery_date}</p>
      <p>Items:</p>
      <ul>#{items_html}</ul>
    </html>
    """
  end
end
