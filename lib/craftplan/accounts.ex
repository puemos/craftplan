defmodule Craftplan.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftplan.Accounts.Token

    resource Craftplan.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
    end
  end
end
