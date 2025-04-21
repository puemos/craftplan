defmodule Craftday.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Craftday.Accounts.User, _opts, _context) do
    Application.fetch_env(:craftday, :token_signing_secret)
  end
end
