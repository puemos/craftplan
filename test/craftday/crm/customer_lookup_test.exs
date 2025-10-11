defmodule Craftday.CRM.CustomerLookupTest do
  use Craftday.DataCase, async: true

  alias Craftday.CRM

  test "get_customer_by_email returns the existing customer" do
    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Alex",
        last_name: "Guest",
        email: "guest@example.com"
      })
      |> Ash.create()

    assert {:ok, found} = CRM.get_customer_by_email("guest@example.com")
    assert found.id == customer.id
  end
end
