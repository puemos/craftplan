defmodule Craftplan.Accounts.Membership.Types.Role do
  @moduledoc false
  use Ash.Type.Enum, values: [:owner, :admin, :staff, :viewer]
end
