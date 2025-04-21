defmodule Craftday.Accounts.User.Types.Role do
  @moduledoc false
  use Ash.Type.Enum, values: [:admin, :staff, :customer]
end
