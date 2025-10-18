defmodule Craftplan.CRM.CustomerLookupTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CRM

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

    {:ok, found} =
      Craftplan.CRM.Customer
      |> Ash.Query.for_read(:get_by_email, %{email: "guest@example.com"})
      |> Ash.read_one(actor: Craftplan.DataCase.staff_actor())

    assert found && found.id == customer.id
  end
end
