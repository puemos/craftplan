defmodule Craftplan.Inventory.SupplierGraphqlFieldsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory.Supplier

  test "Supplier exposes name and contact attributes as public (read via GraphQL/JSON API)" do
    public_names = Supplier |> Ash.Resource.Info.public_attributes() |> Enum.map(& &1.name)

    for attr <- [:name, :contact_name, :contact_email, :contact_phone, :notes] do
      assert attr in public_names,
             "Supplier attribute #{inspect(attr)} is not public — it will not appear in the GraphQL schema."
    end
  end

  test "listing suppliers returns the name attribute populated" do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, _} =
      Supplier
      |> Ash.Changeset.for_create(:create, %{name: "Field Visibility Co"})
      |> Ash.create(actor: actor)

    [supplier | _] =
      [actor: actor]
      |> Craftplan.Inventory.list_suppliers!()
      |> Enum.filter(&(&1.name == "Field Visibility Co"))

    assert supplier.name == "Field Visibility Co"
  end
end
