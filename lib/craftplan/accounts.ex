defmodule Craftplan.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftplan.Accounts.Token

    resource Craftplan.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
      define :list_admin_users, action: :list_admins
    end

    resource Craftplan.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_api_keys_for_user, action: :list_for_user
      define :revoke_api_key, action: :revoke
      define :authenticate_api_key, action: :authenticate
      define :touch_api_key_last_used, action: :touch_last_used
      define :get_api_key_by_id, action: :read, get_by: [:id]
    end
  end
end
