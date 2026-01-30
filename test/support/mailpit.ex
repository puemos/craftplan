defmodule Craftplan.Test.Mailpit do
  @moduledoc """
  Helper for interacting with Mailpit's REST API during e2e tests.

  Mailpit runs on localhost:8025 (API) and localhost:1025 (SMTP).
  Start it via `docker-compose up -d mailpit`.
  """

  @base_url "http://localhost:8025/api/v1"

  @doc """
  Configures Swoosh to use the SMTP adapter pointing at Mailpit (localhost:1025).
  Call this in your test setup.
  """
  def setup_smtp! do
    Application.put_env(:craftplan, Craftplan.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: "localhost",
      port: 1025,
      tls: :never,
      auth: :never
    )
  end

  @doc """
  Deletes all messages from Mailpit's inbox.
  """
  def delete_all! do
    Req.delete!("#{@base_url}/messages")
    :ok
  end

  @doc """
  Searches Mailpit messages. Returns the parsed JSON body.

  `query` uses Mailpit search syntax, e.g. `"to:user@example.com"` or `"subject:Reset"`.
  See https://mailpit.axllent.org/docs/api-v1/view.html#search-messages
  """
  def search_messages(query) do
    resp = Req.get!("#{@base_url}/search", params: [query: query])
    resp.body
  end

  @doc """
  Polls Mailpit until at least one message matching `query` appears.

  Options:
    - `:timeout` — max wait in milliseconds (default: 5000)
    - `:interval` — poll interval in milliseconds (default: 200)

  Returns `{:ok, messages}` or `{:error, :timeout}`.
  """
  def assert_email_received(query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 200)
    deadline = System.monotonic_time(:millisecond) + timeout

    poll(query, interval, deadline)
  end

  defp poll(query, interval, deadline) do
    result = search_messages(query)
    messages = result["messages"] || []

    if messages == [] do
      if System.monotonic_time(:millisecond) >= deadline do
        {:error, :timeout}
      else
        Process.sleep(interval)
        poll(query, interval, deadline)
      end
    else
      {:ok, messages}
    end
  end

  @doc """
  Returns the full message (with HTML body) for a given message ID.
  """
  def get_message(id) do
    resp = Req.get!("#{@base_url}/message/#{id}")
    resp.body
  end
end
