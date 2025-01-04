defmodule Microcraft.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Microcraft.Accounts.User, _opts) do
    Application.fetch_env(:microcraft, :token_signing_secret)
  end
end
