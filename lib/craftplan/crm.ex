defmodule Craftplan.CRM do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftplan.CRM.Customer do
      define :get_customer_by_id, action: :read, get_by: [:id]
      define :get_customer_by_reference, action: :read, get_by: [:reference]
      define :get_customer_by_email, args: [:email], action: :get_by_email
      define :list_customers, action: :list
      define :list_customers_with_keyset, action: :keyset
    end
  end
end
