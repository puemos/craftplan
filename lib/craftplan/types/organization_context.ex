defmodule Craftplan.Types.OrganizationContext do
  @moduledoc """
  Shared struct used to carry organization-specific runtime configuration across the app.
  """
  @enforce_keys [:organization]
  defstruct organization: nil,
            features: [],
            timezone: "UTC",
            locale: "en",
            billing: %{},
            branding: %{}

  @type t :: %__MODULE__{
          organization: Ash.Resource.record(),
          features: [atom()],
          timezone: String.t(),
          locale: String.t(),
          billing: map(),
          branding: map()
        }
end
