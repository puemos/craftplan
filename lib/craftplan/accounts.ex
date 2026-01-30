defmodule Craftplan.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftplan.Accounts.Token

    resource Craftplan.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
    end

    resource Craftplan.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_api_keys_for_user, action: :list_for_user
      define :revoke_api_key, action: :revoke
      define :authenticate_api_key, action: :authenticate
      define :touch_api_key_last_used, action: :touch_last_used
    end
  end
end
