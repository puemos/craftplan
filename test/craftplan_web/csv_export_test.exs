defmodule CraftplanWeb.CSVExportTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.CSV.Exporters.Orders
  alias Craftplan.Test.Factory
  alias NimbleCSV.RFC4180, as: CSV

  describe "CSV export controller" do
    @tag role: :admin
    test "exports orders CSV with correct headers and row data", %{conn: conn, user: user} do
      customer = Factory.create_customer!(%{first_name: "Alice", last_name: "Smith"}, user)
      product = Factory.create_product!(%{name: "Croissant"}, user)

      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 5, unit_price: Decimal.new("3.00")}],
        actor: user
      )

      conn = get(conn, ~p"/manage/settings/csv/export/orders")

      assert response_content_type(conn, :csv) =~ "text/csv"

      body = response(conn, 200)
      [header | rows] = CSV.parse_string(body, skip_headers: false)

      assert header == [
               "reference",
               "currency",
               "delivery_date",
               "invoice_number",
               "invoice_status",
               "payment_method",
               "payment_status",
               "status",
               "subtotal",
               "tax_total",
               "total",
               "customer_name"
             ]

      assert length(rows) >= 1
      [row | _] = rows
      # Last column is customer_name
      assert List.last(row) == "Alice Smith"
      # reference starts with OR_
      assert hd(row) =~ "OR_"
    end

    @tag role: :admin
    test "orders export filename contains entity and today's date", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/orders")

      [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "orders_"
      assert disposition =~ Date.to_iso8601(Date.utc_today())
      assert disposition =~ ".csv"
    end

    @tag role: :admin
    test "exports multiple order rows", %{conn: conn, user: user} do
      customer = Factory.create_customer!(%{first_name: "Multi", last_name: "Test"}, user)
      product = Factory.create_product!(%{name: "Bread"}, user)

      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("2.00")}],
        actor: user
      )

      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 3, unit_price: Decimal.new("4.00")}],
        actor: user
      )

      conn = get(conn, ~p"/manage/settings/csv/export/orders")
      body = response(conn, 200)
      [_header | rows] = CSV.parse_string(body, skip_headers: false)

      assert length(rows) >= 2
    end

    @tag role: :admin
    test "exports customers CSV with correct headers and row data", %{conn: conn, user: user} do
      Factory.create_customer!(
        %{first_name: "Bob", last_name: "Jones", email: "bob@test.com"},
        user
      )

      conn = get(conn, ~p"/manage/settings/csv/export/customers")
      body = response(conn, 200)
      [header | rows] = CSV.parse_string(body, skip_headers: false)

      assert header == ["reference", "type", "first_name", "last_name", "email", "phone"]
      assert length(rows) >= 1

      [row | _] = rows
      # reference starts with CUS_
      assert Enum.at(row, 0) =~ "CUS_"
      assert Enum.at(row, 1) == "individual"
      assert Enum.at(row, 2) == "Bob"
      assert Enum.at(row, 3) == "Jones"
      assert Enum.at(row, 4) == "bob@test.com"
    end

    @tag role: :admin
    test "exports movements CSV with correct headers", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/movements")
      body = response(conn, 200)
      [header | _rows] = CSV.parse_string(body, skip_headers: false)

      assert header == ["quantity", "reason", "occurred_at", "material_name", "lot_number"]
    end

    @tag role: :admin
    test "exports movements CSV with actual movement data", %{conn: conn, user: user} do
      material = Factory.create_material!(%{name: "Flour"}, user)

      lot =
        Craftplan.Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-#{System.unique_integer([:positive])}",
          material_id: material.id
        })
        |> Ash.create!(actor: user)

      Craftplan.Inventory.adjust_stock!(
        %{
          quantity: Decimal.new("100"),
          reason: "Received",
          material_id: material.id,
          lot_id: lot.id
        },
        actor: user
      )

      conn = get(conn, ~p"/manage/settings/csv/export/movements")
      body = response(conn, 200)
      [_header | rows] = CSV.parse_string(body, skip_headers: false)

      assert length(rows) >= 1
      [row | _] = rows
      assert Enum.at(row, 0) == "100"
      assert Enum.at(row, 1) == "Received"
      assert Enum.at(row, 3) == "Flour"
    end

    @tag role: :admin
    test "returns redirect for unknown entity", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/foobar")
      assert redirected_to(conn) == "/manage/settings/csv"
    end

    @tag role: :staff
    test "staff user can export orders", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/orders")
      assert response_content_type(conn, :csv) =~ "text/csv"
      body = response(conn, 200)
      [header | _] = CSV.parse_string(body, skip_headers: false)
      assert "reference" in header
    end

    @tag role: :staff
    test "staff user can export customers", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/customers")
      assert response_content_type(conn, :csv) =~ "text/csv"
    end

    @tag role: :staff
    test "staff user can export movements", %{conn: conn} do
      conn = get(conn, ~p"/manage/settings/csv/export/movements")
      assert response_content_type(conn, :csv) =~ "text/csv"
    end
  end

  describe "CSV export LiveView integration" do
    test "export form submits and redirects to download endpoint", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

      # The form should exist with the entity select
      assert has_element?(view, "#csv-export-form")
      assert has_element?(view, ~s(select[name="entity"]))

      result =
        view
        |> form("#csv-export-form", %{"entity" => "orders"})
        |> render_submit()

      # LiveView redirect returns {:error, {:redirect, %{to: url}}} which
      # follow_redirect converts; we just verify the redirect happens
      assert {:error, {:redirect, %{to: "/manage/settings/csv/export/orders"}}} = result
    end

    test "can select different entities for export", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, html} = live(conn, ~p"/manage/settings/csv")

      assert html =~ "Export data"
      assert html =~ "Entity to export"

      # All three entities should be available
      assert html =~ "Orders"
      assert html =~ "Customers"
      assert html =~ "Inventory movements"

      # Select customers and verify redirect target
      result =
        view
        |> form("#csv-export-form", %{"entity" => "customers"})
        |> render_submit()

      assert {:error, {:redirect, %{to: "/manage/settings/csv/export/customers"}}} = result
    end
  end

  describe "exporter modules" do
    test "orders exporter produces parseable CSV with headers and no data rows when empty" do
      actor = Craftplan.DataCase.staff_actor()
      csv = Orders.export(actor)

      assert is_binary(csv)
      [header | rows] = CSV.parse_string(csv, skip_headers: false)
      assert length(header) == 12
      assert rows == []
    end

    test "orders exporter includes all expected columns" do
      actor = Craftplan.DataCase.staff_actor()
      customer = Factory.create_customer!(%{first_name: "Ex", last_name: "Port"}, actor)
      product = Factory.create_product!(%{name: "Baguette"}, actor)

      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 2, unit_price: Decimal.new("1.50")}],
        actor: actor
      )

      csv = Orders.export(actor)
      [_header | rows] = CSV.parse_string(csv, skip_headers: false)
      assert length(rows) == 1

      [row] = rows
      assert length(row) == 12
      # reference column
      assert Enum.at(row, 0) =~ "OR_"
      # currency column
      assert Enum.at(row, 1) == "USD"
      # customer_name column (last)
      assert Enum.at(row, 11) == "Ex Port"
    end

    test "customers exporter produces parseable CSV" do
      actor = Craftplan.DataCase.staff_actor()
      csv = Craftplan.CSV.Exporters.Customers.export(actor)

      assert is_binary(csv)
      [header | _] = CSV.parse_string(csv, skip_headers: false)
      assert length(header) == 6
    end

    test "movements exporter produces parseable CSV" do
      actor = Craftplan.DataCase.staff_actor()
      csv = Craftplan.CSV.Exporters.Movements.export(actor)

      assert is_binary(csv)
      [header | _] = CSV.parse_string(csv, skip_headers: false)
      assert length(header) == 5
    end
  end
end
