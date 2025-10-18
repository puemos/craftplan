defmodule Craftplan.Inventory.SuppliersTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory

  test "create, list (sorted), and update supplier" do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, s1} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Zeta Foods",
        contact_email: "hello@zeta.test"
      })
      |> Ash.create(actor: actor)

    {:ok, s2} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Alpha Ingredients",
        contact_email: "hi@alpha.test"
      })
      |> Ash.create(actor: actor)

    # list is sorted by name asc
    list = Inventory.list_suppliers!(actor: actor)
    assert Enum.map(list, & &1.id) == Enum.map(Enum.sort_by([s2, s1], & &1.name), & &1.id)

    # update supplier
    {:ok, s2u} =
      s2
      |> Ash.Changeset.for_update(:update, %{contact_phone: "+123"})
      |> Ash.update(actor: actor)

    assert s2u.contact_phone == "+123"
  end
end
