defmodule CraftplanWeb.ManagePurchasingLiveTest do
  @moduledoc false

  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.PurchaseOrder
  alias Craftplan.Inventory.Supplier

  defp create_supplier!(attrs \\ %{}) do
    staff = Craftplan.DataCase.staff_actor()
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
    staff = Craftplan.DataCase.staff_actor()

    PurchaseOrder
    |> Ash.Changeset.for_create(:create, %{
      supplier_id: supplier.id,
      ordered_at: DateTime.utc_now()
    })
    |> Ash.create!(actor: staff)
  end

  describe "purchase orders index and modals" do
    @tag role: :staff
    test "renders purchase orders index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/purchasing")
      assert has_element?(view, "#purchase-orders")
    end

    @tag role: :staff
    test "renders new PO modal", %{conn: conn} do
      _sup = create_supplier!()

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/new")
      assert has_element?(view, "#po-new-modal")
    end

    @tag role: :staff
    test "renders add item modal for existing PO", %{conn: conn} do
      sup = create_supplier!()
      po = create_po!(sup)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}/add_item")
      assert has_element?(view, "#po-item-modal")
    end
  end

  describe "suppliers" do
    @tag role: :staff
    test "renders suppliers list and new modal", %{conn: conn} do
      _sup = create_supplier!()

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers")
      assert has_element?(view, "#suppliers")

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers/new")
      assert has_element?(view, "#supplier-modal")
    end

    @tag role: :staff
    test "renders supplier edit modal", %{conn: conn} do
      sup = create_supplier!()

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/suppliers/#{sup.id}/edit")
      assert has_element?(view, "#supplier-modal")
    end
  end

  describe "purchase order show" do
    @tag role: :staff
    test "renders overview and items tabs", %{conn: conn} do
      sup = create_supplier!()
      po = create_po!(sup)

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}")
      assert has_element?(view, "[role=tablist]")
      assert render(view) =~ po.reference

      {:ok, view, _html} = live(conn, ~p"/manage/purchasing/#{po.reference}/items")
      assert has_element?(view, "#po-items")
    end
  end
end
