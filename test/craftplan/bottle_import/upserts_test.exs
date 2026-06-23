defmodule Craftplan.BottleImport.UpsertsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.BottleImport.Upserts
  alias Craftplan.Catalog.Product
  alias Craftplan.Orders.Order

  defp actor, do: Craftplan.DataCase.staff_actor()

  defp customer_row(overrides) do
    Map.merge(
      %{
        "Customer Name" => "Edward Yardley",
        "Email" => "edward@example.com",
        "Phone" => "(202) 590-8525",
        "Address1" => "508 7th St NE",
        "Address2" => nil,
        "City" => "Washington",
        "State" => "DC",
        "Zip" => "20002"
      },
      overrides
    )
  end

  describe "upsert_customer/2" do
    test "creates a new customer when phone is unique" do
      {:ok, c} = Upserts.upsert_customer(customer_row(%{}), actor())
      assert c.first_name == "Edward"
      assert c.last_name == "Yardley"
      assert c.phone == "2025908525"
    end

    test "updates an existing customer's shipping address when phone matches" do
      {:ok, first} = Upserts.upsert_customer(customer_row(%{}), actor())
      assert first.shipping_address.street == "508 7th St NE"

      {:ok, second} =
        Upserts.upsert_customer(
          customer_row(%{"Address1" => "999 New Address", "Zip" => "20003"}),
          actor()
        )

      assert second.id == first.id
      assert second.shipping_address.street == "999 New Address"
      assert second.shipping_address.zip == "20003"
    end

    test "handles mononyms via NameParser (first_name = -)" do
      {:ok, c} =
        Upserts.upsert_customer(
          customer_row(%{"Customer Name" => "Spackey", "Phone" => "(216) 798-1313"}),
          actor()
        )

      # NameParser returns "-" for mononym first_name, which is also what Customer stores.
      assert c.first_name == "-"
      assert c.last_name == "Spackey"
    end
  end

  describe "resolve_product/5" do
    test "returns the existing Product when SKU is found" do
      _existing =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Pain de Ville",
          sku: "BOTTLE-PID-47420",
          price: Decimal.new("10.00"),
          status: :active
        })
        |> Ash.create!(actor: actor())

      {:ok, found} =
        Upserts.resolve_product("PID-47420", "Pain de Ville", "manufactured", %{}, actor())

      assert found.sku == "BOTTLE-PID-47420"
      assert Decimal.equal?(found.price, Decimal.new("10.00"))
    end

    test "creates a new Product from price_map when SKU isn't in DB" do
      {:ok, created} =
        Upserts.resolve_product(
          "PID-99999",
          "Brand New Loaf",
          "manufactured",
          %{"PID-99999" => Decimal.new("12.50")},
          actor()
        )

      assert created.sku == "BOTTLE-PID-99999"
      assert Decimal.equal?(created.price, Decimal.new("12.50"))
      assert created.selling_availability == :available
      assert created.status == :active
    end

    test "creates kit products with selling_availability: :off and preserves name verbatim" do
      {:ok, created} =
        Upserts.resolve_product(
          "PID-96931",
          "Combo Box (2 of each)",
          "kit",
          %{"PID-96931" => Decimal.new("40.00")},
          actor()
        )

      assert created.selling_availability == :off
      assert created.name == "Combo Box (2 of each)"
    end

    test "errors when PID is unknown to both DB and price_map" do
      assert {:error, {:unknown_pid, %{pid: "PID-77777", name: "Mystery"}}} =
               Upserts.resolve_product("PID-77777", "Mystery", "manufactured", %{}, actor())
    end
  end

  describe "upsert_order/4" do
    setup do
      {:ok, _} = Upserts.upsert_customer(customer_row(%{}), actor())

      {:ok, _} =
        Upserts.resolve_product(
          "PID-47420",
          "Pain de Ville",
          "manufactured",
          %{"PID-47420" => Decimal.new("10.00")},
          actor()
        )

      :ok
    end

    test "creates a new order with its items" do
      order_row = %{
        "Bottle ID" => "10423992",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, order} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert order.invoice_number == "BOTTLE-10423992"
      assert order.delivery_method == :delivery
      assert order.payment_status == :paid
      assert order.status == :completed
      assert order.delivery_date == ~U[2026-01-13 10:00:00Z]
    end

    test "is idempotent — second call with same Bottle ID returns :skip" do
      order_row = %{
        "Bottle ID" => "10423992",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, _} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert {:skip, :already_imported} =
               Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())
    end

    test "maps Maketto Pickup to :pickup" do
      order_row = %{
        "Bottle ID" => "10423993",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Maketto Pickup"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, order} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert order.delivery_method == :pickup
    end

    test "blocks the order with unknown PID and writes nothing" do
      order_row = %{
        "Bottle ID" => "10423994",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-77777", "quantity" => 1}]

      assert {:error, {:unknown_pid, _}} =
               Upserts.upsert_order(order_row, items, %{}, actor())

      assert {:ok, []} = Ash.read(Order, action: :read, actor: actor())
    end
  end
end
