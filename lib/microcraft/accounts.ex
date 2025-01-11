defmodule Microcraft.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Microcraft.Accounts.Token

    resource Microcraft.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
    end
  end
end
