defmodule CraftplanWeb.CalendarFeedTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias Craftplan.Orders.ProductionBatch
  alias Craftplan.Test.Factory

  describe "GET /api/calendar/feed.ics" do
    # ── Auth: no key / bad key / wrong prefix ──

    test "returns 401 when no API key provided", %{conn: conn} do
      conn = get(conn, "/api/calendar/feed.ics")
      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "returns 401 when invalid API key provided", %{conn: conn} do
      conn = get(conn, "/api/calendar/feed.ics?key=cpk_invalid_key_here")
      assert conn.status == 401
    end

    test "returns 401 when key param is missing cpk_ prefix", %{conn: conn} do
      conn = get(conn, "/api/calendar/feed.ics?key=not_a_valid_key")
      assert conn.status == 401
    end

    test "returns 401 for a revoked API key", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()
      {raw_key, api_key} = Factory.create_api_key!(%{"orders" => ["read"]}, admin)

      # Revoke the key
      Accounts.revoke_api_key(api_key, actor: admin)

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      assert conn.status == 401
    end

    # ── Happy path: orders appear with correct data ──

    test "returns valid iCal with order events containing reference and customer name", %{
      conn: conn
    } do
      # Key needs orders + customers scope to see customer names on order events
      {raw_key, _api_key} =
        Factory.create_api_key!(%{"orders" => ["read"], "customers" => ["read"]})

      customer = Factory.create_customer!(%{first_name: "Alice", last_name: "Baker"})
      product = Factory.create_product!(%{name: "Sourdough Loaf"})

      order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 5, unit_price: Decimal.new("10.00")}],
          delivery_date: DateTime.utc_now()
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")

      assert conn.status == 200

      # Correct headers
      assert conn |> get_resp_header("content-type") |> List.first() =~ "text/calendar"
      assert conn |> get_resp_header("content-disposition") |> List.first() =~ "craftplan.ics"

      body = conn.resp_body

      # Valid iCal structure
      assert body =~ "BEGIN:VCALENDAR"
      assert body =~ "END:VCALENDAR"
      assert body =~ "BEGIN:VEVENT"
      assert body =~ "END:VEVENT"

      # Contains the order reference and customer name
      assert body =~ order.reference
      assert body =~ "Alice Baker"
      assert body =~ "order-#{order.id}@craftplan"
    end

    test "returns multiple order events when multiple orders exist in window", %{conn: conn} do
      {raw_key, _api_key} =
        Factory.create_api_key!(%{"orders" => ["read"], "customers" => ["read"]})

      customer = Factory.create_customer!()
      product = Factory.create_product!()

      order1 =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 2, unit_price: Decimal.new("8.00")}],
          delivery_date: DateTime.utc_now()
        )

      order2 =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 3, unit_price: Decimal.new("12.00")}],
          delivery_date: DateTime.add(DateTime.utc_now(), 7, :day)
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert body =~ order1.reference
      assert body =~ order2.reference

      # Two VEVENT blocks
      assert length(String.split(body, "BEGIN:VEVENT")) == 3
    end

    # ── Date window filtering ──

    test "excludes orders older than 30 days", %{conn: conn} do
      {raw_key, _api_key} = Factory.create_api_key!(%{"orders" => ["read"]})

      customer = Factory.create_customer!()
      product = Factory.create_product!()

      old_order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.add(DateTime.utc_now(), -60, :day)
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      assert body =~ "BEGIN:VCALENDAR"
      refute body =~ old_order.reference
      refute body =~ "BEGIN:VEVENT"
    end

    test "excludes orders more than 90 days in the future", %{conn: conn} do
      {raw_key, _api_key} = Factory.create_api_key!(%{"orders" => ["read"]})

      customer = Factory.create_customer!()
      product = Factory.create_product!()

      future_order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.add(DateTime.utc_now(), 120, :day)
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      refute body =~ future_order.reference
    end

    test "includes order within window and excludes one outside", %{conn: conn} do
      {raw_key, _api_key} = Factory.create_api_key!(%{"orders" => ["read"]})

      customer = Factory.create_customer!()
      product = Factory.create_product!()

      recent_order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.add(DateTime.utc_now(), -10, :day)
        )

      old_order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.add(DateTime.utc_now(), -45, :day)
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert body =~ recent_order.reference
      refute body =~ old_order.reference
    end

    # ── Scope enforcement ──

    test "key with orders scope but no customers scope shows order events with Unknown customer",
         %{
           conn: conn
         } do
      {raw_key, _api_key} = Factory.create_api_key!(%{"orders" => ["read"]})

      customer = Factory.create_customer!(%{first_name: "Secret", last_name: "Person"})
      product = Factory.create_product!()

      order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.utc_now()
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      assert body =~ "BEGIN:VEVENT"
      assert body =~ order.reference
      # Customer name not accessible without customers:read scope
      assert body =~ "Unknown"
      refute body =~ "Secret Person"
    end

    test "key without orders scope returns empty feed (no order events leak)", %{conn: conn} do
      {raw_key, _api_key} = Factory.create_api_key!(%{"products" => ["read"]})

      customer = Factory.create_customer!()
      product = Factory.create_product!()

      order =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: Decimal.new("5.00")}],
          delivery_date: DateTime.utc_now()
        )

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      assert body =~ "BEGIN:VCALENDAR"
      refute body =~ order.reference
      refute body =~ "BEGIN:VEVENT"
    end

    # ── Production batches ──

    test "includes started production batch events", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      {raw_key, _api_key} =
        Factory.create_api_key!(%{"orders" => ["read"], "production_batches" => ["read"]}, admin)

      product = Factory.create_product!(admin)

      # Create and start a batch
      batch =
        ProductionBatch
        |> Ash.Changeset.for_create(:open, %{
          product_id: product.id,
          planned_qty: Decimal.new("100")
        })
        |> Ash.create!(actor: admin)

      batch =
        batch
        |> Ash.Changeset.for_update(:start, %{})
        |> Ash.update!(actor: admin)

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      assert body =~ "BEGIN:VEVENT"
      assert body =~ "Batch #{batch.batch_code}"
      assert body =~ "batch-#{batch.id}@craftplan"
    end

    # ── Empty feed ──

    test "returns valid empty iCal when no resources exist", %{conn: conn} do
      {raw_key, _api_key} = Factory.create_api_key!(%{"orders" => ["read"]})

      conn = get(conn, "/api/calendar/feed.ics?key=#{raw_key}")
      body = conn.resp_body

      assert conn.status == 200
      assert body =~ "BEGIN:VCALENDAR"
      assert body =~ "END:VCALENDAR"
      refute body =~ "BEGIN:VEVENT"
    end
  end
end
