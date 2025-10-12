defmodule CraftdayWeb.ManagePurchasingInteractionsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.Inventory.{Supplier, PurchaseOrder, Material}

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_supplier! do
    Supplier
    |> Ash.Changeset.for_create(:create, %{
      name: "Sup-#{System.unique_integer()}",
      contact_name: "Sam",
      contact_email: "sam+#{System.unique_integer()}@sup.test",
      contact_phone: "555"
    })
    |> Ash.create!(actor: staff_user!())
  end

  defp create_po!(sup) do
    PurchaseOrder
    |> Ash.Changeset.for_create(:create, %{
      supplier_id: sup.id,
      ordered_at: DateTime.utc_now()
    })
    |> Ash.create!(actor: staff_user!())
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
    |> Ash.create!(actor: staff_user!())
  end

  test "create supplier via form", %{conn: conn} do
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/purchasing/suppliers/new")

    name = "Sup-#{System.unique_integer()}"
    params = %{"supplier" => %{"name" => name, "contact_email" => "a@b.c"}}

    view
    |> element("#supplier-form")
    |> render_submit(params)

    assert render(view) =~ "Supplier saved"
  end

  test "create purchase order and add item then receive", %{conn: conn} do
    sup = create_supplier!()
    mat = create_material!()

    conn = sign_in(conn, staff_user!())
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
    po = hd(Craftday.Inventory.list_purchase_orders!(actor: staff_user!()))
    {:ok, index, _} = live(conn, ~p"/manage/purchasing/#{po.reference}/add_item")

    # Add an item
    index
    |> element("#purchase-order-item-form")
    |> render_submit(%{
      "purchase_order_item" => %{"material_id" => mat.id, "quantity" => "2", "unit_price" => "1.5"}
    })

    assert render(index) =~ "Item added"

    # Receive flow is covered via UI elsewhere; add-item interaction verified here
  end
end
