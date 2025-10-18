defmodule CraftplanWeb.ManagePurchasingInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.Supplier

  defp create_supplier! do
    Supplier
    |> Ash.Changeset.for_create(:create, %{
      name: "Sup-#{System.unique_integer()}",
      contact_name: "Sam",
      contact_email: "sam+#{System.unique_integer()}@sup.test",
      contact_phone: "555"
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      price: Decimal.new("1.00"),
      unit: :gram,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "create supplier via form", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/manage/purchasing/suppliers/new")

    name = "Sup-#{System.unique_integer()}"
    params = %{"supplier" => %{"name" => name, "contact_email" => "a@b.c"}}

    view
    |> element("#supplier-form")
    |> render_submit(params)

    assert render(view) =~ "Supplier saved"
  end

  @tag role: :staff
  test "create purchase order and add item then receive", %{conn: conn} do
    sup = create_supplier!()
    mat = create_material!()

    {:ok, view, _} = live(conn, ~p"/manage/purchasing/new")

    po_params = %{
      "purchase_order" => %{
        "supplier_id" => sup.id,
        "status" => "ordered",
        "ordered_at" => "2025-01-01T10:00"
      }
    }

    view
    |> element("#purchase-order-form")
    |> render_submit(po_params)

    assert render(view) =~ "Purchase order"

    # Fetch created PO and navigate to add_item directly
    po = hd(Craftplan.Inventory.list_purchase_orders!(actor: Craftplan.DataCase.staff_actor()))
    {:ok, index, _} = live(conn, ~p"/manage/purchasing/#{po.reference}/add_item")

    # Add an item
    index
    |> element("#purchase-order-item-form")
    |> render_submit(%{
      "purchase_order_item" => %{
        "material_id" => mat.id,
        "quantity" => "2",
        "unit_price" => "1.5"
      }
    })

    assert render(index) =~ "Item added"

    # Navigate to show and mark received
    {:ok, show, _} = live(conn, ~p"/manage/purchasing/#{po.reference}")

    show
    |> element("a[phx-click]")
    |> render_click()

    # Revisit show to assert status updated
    {:ok, show2, _} = live(conn, ~p"/manage/purchasing/#{po.reference}")
    assert render(show2) =~ "received"
  end
end
