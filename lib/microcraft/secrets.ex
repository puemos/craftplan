defmodule CraftScale.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], CraftScale.Accounts.User, _opts) do
    Application.fetch_env(:craftscale, :token_signing_secret)
  end
end
