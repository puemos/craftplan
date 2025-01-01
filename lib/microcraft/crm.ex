defmodule Microcraft.CRM do
  use Ash.Domain

  resources do
    resource Microcraft.CRM.Customer do
      define :get_customer_by_id, action: :read, get_by: [:id]
      define :list_customers, action: :list
      define :list_customers_with_keyset, action: :keyset
    end
  end
end
