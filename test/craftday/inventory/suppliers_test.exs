defmodule Craftday.Inventory.SuppliersTest do
  use Craftday.DataCase, async: true

  alias Craftday.Inventory

  test "create, list (sorted), and update supplier" do
    {:ok, s1} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Zeta Foods",
        contact_email: "hello@zeta.test"
      })
      |> Ash.create()

    {:ok, s2} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Alpha Ingredients",
        contact_email: "hi@alpha.test"
      })
      |> Ash.create()

    # list is sorted by name asc
    list = Inventory.list_suppliers!()
    assert Enum.map(list, & &1.id) == Enum.map(Enum.sort_by([s2, s1], & &1.name), & &1.id)

    # update supplier
    {:ok, s2u} =
      s2
      |> Ash.Changeset.for_update(:update, %{contact_phone: "+123"})
      |> Ash.update()

    assert s2u.contact_phone == "+123"
  end
end
