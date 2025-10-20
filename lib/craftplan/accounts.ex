defmodule Craftplan.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftplan.Accounts.Token

    resource Craftplan.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
    end

    resource Craftplan.Accounts.Membership do
      define :get_membership, args: [:organization_id, :user_id], action: :for_user
      define :list_memberships_for_user, args: [:user_id], action: :list_for_user
    end
  end
end
