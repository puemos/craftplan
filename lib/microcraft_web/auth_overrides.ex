defmodule MicrocraftWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.SignInLive do
    # set :root_class, "grid h-screen place-items-center"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, false
  end
end
