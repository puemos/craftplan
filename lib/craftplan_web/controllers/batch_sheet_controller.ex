defmodule CraftplanWeb.BatchSheetController do
  use CraftplanWeb, :controller

  alias Craftplan.Production.BatchSheet

  require Logger

  def show(conn, %{"batch_code" => batch_code}) do
    actor = conn.assigns[:current_user]

    if is_nil(actor) do
      conn
      |> put_flash(:error, "You must be signed in")
      |> redirect(to: ~p"/sign-in")
    else
      currency = load_currency(actor)

      case BatchSheet.generate_pdf(batch_code, actor: actor, currency: currency) do
        {:ok, pdf_binary} ->
          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header(
            "content-disposition",
            ~s(inline; filename="#{batch_code}.pdf")
          )
          |> send_resp(200, pdf_binary)

        {:error, reason} ->
          Logger.error("Batch sheet PDF generation failed: #{inspect(reason)}")

          conn
          |> put_flash(:error, "Failed to generate batch sheet: #{inspect(reason)}")
          |> redirect(to: ~p"/manage/production/batches/#{batch_code}")
      end
    end
  rescue
    e ->
      Logger.error("Batch sheet error: #{Exception.message(e)}")

      conn
      |> put_flash(:error, "Batch sheet error: #{Exception.message(e)}")
      |> redirect(to: ~p"/manage/production/batches/#{batch_code}")
  end

  defp load_currency(actor) do
    case Craftplan.Settings.get_settings(actor: actor) do
      {:ok, settings} -> settings.currency || :USD
      _ -> :USD
    end
  end
end
