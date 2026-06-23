defmodule Craftplan.BottleImportTest do
  use Craftplan.DataCase, async: false

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order
  alias Mix.Tasks.Bottle.Import, as: ImportTask

  @fixtures Path.expand("../support/bottle_fixtures", __DIR__)
  @price_map Path.join(@fixtures, "price_map.yml")

  defp actor, do: Craftplan.DataCase.staff_actor()

  describe "run/1 (happy path)" do
    test "imports the fixture set" do
      # Ensure a staff user exists so the Mix task's staff_actor!/0 can find one.
      _staff = actor()
      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      assert result.created_customers == 5
      assert result.created_products == 4
      assert result.inserted_orders == 5
      assert result.skipped_orders == 0
      assert result.failed_orders == 0

      assert {:ok, customers} = Ash.read(Customer, actor: actor())
      assert length(customers) == 5

      assert {:ok, products} = Ash.read(Product, actor: actor())
      assert Enum.all?(products, &String.starts_with?(&1.sku, "BOTTLE-PID-"))

      assert {:ok, orders} = Ash.read(Order, action: :read, actor: actor())
      assert length(orders) == 5
    end

    test "second run is a no-op (idempotent)" do
      _staff = actor()
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])
      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      assert result.inserted_orders == 0
      assert result.skipped_orders == 5
      assert result.failed_orders == 0
    end

    test "mononym customer lands as first_name = -" do
      _staff = actor()
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      {:ok, c} =
        Customer
        |> Ash.Query.for_read(:get_by_email, %{email: "spackey@example.com"})
        |> Ash.read_one(actor: actor())

      assert c.first_name == "-"
      assert c.last_name == "Spackey"
    end

    test "Maketto Pickup becomes delivery_method: :pickup" do
      _staff = actor()
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])
      {:ok, orders} = Ash.read(Order, action: :read, actor: actor())
      pickup = Enum.find(orders, &(&1.invoice_number == "BOTTLE-1003"))
      assert pickup.delivery_method == :pickup
    end
  end

  describe "run/1 (unknown PID path)" do
    test "blocks the run and writes nothing" do
      _staff = actor()
      empty_map = Path.join(@fixtures, "empty_price_map.yml")
      File.write!(empty_map, "prices: {}\n")
      on_exit(fn -> File.rm(empty_map) end)

      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", empty_map])

      assert result.unknown_pids != []
      assert result.inserted_orders == 0

      assert {:ok, customers} = Ash.read(Customer, actor: actor())
      assert customers == []

      assert {:ok, orders} = Ash.read(Order, action: :read, actor: actor())
      assert orders == []
    end
  end
end
