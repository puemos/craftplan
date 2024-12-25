defmodule Microcraft.Accounts.User.Types.Role do
  use Ash.Type.Enum, values: [:admin, :staff, :customer]
end
