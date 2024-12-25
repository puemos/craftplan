defmodule Microcraft.Accounts do
  use Ash.Domain

  resources do
    resource Microcraft.Accounts.Token
    resource Microcraft.Accounts.User
  end
end
