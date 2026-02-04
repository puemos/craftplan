defmodule CraftplanWeb.CommandPaletteTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  defp staff_conn(conn) do
    staff = Craftplan.DataCase.staff_actor()

    conn =
      conn
      |> AshAuthentication.Phoenix.Plug.store_in_session(staff)
      |> Plug.Conn.assign(:current_user, staff)

    {conn, staff}
  end

  describe "command palette" do
    test "renders search button in header for authenticated users", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, _view, html} = live(conn, ~p"/manage/overview")

      assert html =~ "command-palette"
      assert html =~ "Search..."
    end

    test "opens when clicking the search button", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      # Click the search button (targeting the component)
      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Modal should be open
      html = render(view)
      assert html =~ "Search pages, actions, or records..."
      assert html =~ "to navigate"
    end

    test "shows static pages when first opened", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      html = render(view)
      assert html =~ "Pages"
      assert html =~ "Overview"
      assert html =~ "Orders"
      assert html =~ "Inventory"
      assert html =~ "Products"
    end

    test "shows static actions when first opened", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      html = render(view)
      assert html =~ "Actions"
      assert html =~ "New Order"
      assert html =~ "New Product"
      assert html =~ "New Customer"
    end

    test "filters results when searching", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Search for "order"
      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "order"})

      html = render(view)
      # Should show pages/actions containing "order"
      assert html =~ "Orders"
      assert html =~ "New Order"
      # Should not show unrelated static pages (check within the command palette results)
      # Note: Inventory appears in the sidebar, so we check it's not in the pages section results
      refute html =~ ~r/<button[^>]*>.*New Material.*<\/button>/s
    end

    test "closes when clicking backdrop", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()
      assert render(view) =~ "Search pages, actions, or records..."

      view
      |> element("#command-palette")
      |> render_hook("close", %{})

      refute render(view) =~ "Search pages, actions, or records..."
    end

    test "searches products by name", %{conn: conn} do
      {conn, staff} = staff_conn(conn)

      # Create a test product
      product = Factory.create_product!(%{name: "Chocolate Cake", sku: "choc-cake-001"}, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "chocolate"})

      html = render(view)
      assert html =~ "Chocolate Cake"
      assert html =~ product.sku
    end

    test "searches materials by name", %{conn: conn} do
      {conn, staff} = staff_conn(conn)

      # Create a test material
      material = Factory.create_material!(%{name: "Cocoa Powder", sku: "cocoa-001"}, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "cocoa"})

      html = render(view)
      assert html =~ "Cocoa Powder"
      assert html =~ material.sku
    end

    test "searches customers by name", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      # Create a test customer
      _customer = Factory.create_customer!(%{first_name: "Alice", last_name: "Smith"})

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "alice"})

      html = render(view)
      assert html =~ "Alice Smith"
    end

    test "shows no results message when nothing matches", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      view
      |> element("#command-palette")
      |> render_hook("search", %{query: "xyznonexistent123"})

      html = render(view)
      assert html =~ "No results found"
      assert html =~ "xyznonexistent123"
    end

    test "navigates down through results", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Navigate down
      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      # First item should no longer be selected, second should be
      html = render(view)
      # The selected item gets bg-stone-100 class
      assert html =~ "bg-stone-100"
    end

    test "navigates up through results", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Navigate down twice then up
      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "down"})

      view
      |> element("#command-palette")
      |> render_hook("navigate", %{direction: "up"})

      # Verify we can navigate
      assert render(view) =~ "bg-stone-100"
    end

    test "selects item and navigates", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Click on the Orders page item
      view
      |> element("#command-palette button[phx-value-path='/manage/orders']")
      |> render_click()

      # Should navigate to orders page
      assert_redirect(view, ~p"/manage/orders")
    end

    test "selects item via keyboard enter", %{conn: conn} do
      {conn, _staff} = staff_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/overview")

      view |> element("#command-palette button[phx-click=open]") |> render_click()

      # Select current item with enter
      view
      |> element("#command-palette")
      |> render_hook("select", %{})

      # Should navigate to first item (Overview)
      assert_redirect(view, ~p"/manage/overview")
    end
  end
end
