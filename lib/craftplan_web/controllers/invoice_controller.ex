defmodule CraftplanWeb.InvoiceController do
  use CraftplanWeb, :controller

  alias Craftplan.Orders.InvoicePdf

  require Logger

  def show(conn, %{"reference" => reference}) do
    actor = conn.assigns[:current_user]

    if is_nil(actor) do
      conn
      |> put_flash(:error, "You must be signed in")
      |> redirect(to: ~p"/sign-in")
    else
      currency = load_currency(actor)

      case InvoicePdf.generate_pdf(reference, actor: actor, currency: currency) do
        {:ok, pdf_binary} ->
          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header(
            "content-disposition",
            ~s(inline; filename="#{reference}.pdf")
          )
          |> send_resp(200, pdf_binary)

        {:error, reason} ->
          Logger.error("Invoice PDF generation failed: #{inspect(reason)}")

          conn
          |> put_flash(:error, "Failed to generate invoice: #{inspect(reason)}")
          |> redirect(to: ~p"/manage/orders/#{reference}")
      end
    end
  rescue
    e ->
      Logger.error("Invoice error: #{Exception.message(e)}")

      conn
      |> put_flash(:error, "Invoice error: #{Exception.message(e)}")
      |> redirect(to: ~p"/manage/orders/#{reference}")
  end

  defp load_currency(actor) do
    case Craftplan.Settings.get_settings(actor: actor) do
      {:ok, settings} -> settings.currency || :USD
      _ -> :USD
    end
  end
end
