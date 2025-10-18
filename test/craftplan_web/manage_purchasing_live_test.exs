defmodule CraftplanWeb.ManagePurchasingLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.PurchaseOrder
  alias Craftplan.Inventory.Supplier

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_supplier!(attrs \\ %{}) do
    staff = staff_user!()
    name = Map.get(attrs, :name, "Acme Supplies #{System.unique_integer()}")

    Supplier
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      contact_name: "Sam",
      contact_email: "sam+#{System.unique_integer()}@acme.test",
      contact_phone: "1234567"
    })
    |> Ash.create!(actor: staff)
  end

  defp create_po!(supplier) do
    staff = staff_user!()

    PurchaseOrder
    |> Ash.Changeset.for_create(:create, %{
      supplier_id: supplier.id,
      ordered_at: DateTime.utc_now()
    })
    |> Ash.create!(actor: staff)
  end

  describe "purchase orders index and modals" do
    test "renders purchase orders index for staff", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing")
      assert has_element?(view, "#purchase-orders")
    end

    test "renders new PO modal", %{conn: conn} do
      _sup = create_supplier!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/new")
      assert has_element?(view, "#po-new-modal")
    end

    test "renders add item modal for existing PO", %{conn: conn} do
      sup = create_supplier!()
      po = create_po!(sup)
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}/add_item")
      assert has_element?(view, "#po-item-modal")
    end
  end

  describe "suppliers" do
    test "renders suppliers list and new modal", %{conn: conn} do
      _sup = create_supplier!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers")
      assert has_element?(view, "#suppliers")

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers/new")
      assert has_element?(view, "#supplier-modal")
    end

    test "renders supplier edit modal", %{conn: conn} do
      sup = create_supplier!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers/#{sup.id}/edit")
      assert has_element?(view, "#supplier-modal")
    end
  end

  describe "purchase order show" do
    test "renders overview and items tabs", %{conn: conn} do
      sup = create_supplier!()
      po = create_po!(sup)
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}")
      assert has_element?(view, "[role=tablist]")
      assert render(view) =~ po.reference

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}/items")
      assert has_element?(view, "#po-items")
    end
  end
end
