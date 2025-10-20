defmodule Craftplan.Accounts.Membership.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:pending, :active, :suspended]
end
