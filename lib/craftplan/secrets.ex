defmodule Craftplan.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Craftplan.Accounts.User, _opts, _context) do
    Application.fetch_env(:craftplan, :token_signing_secret)
  end
end
