defmodule Craftplan.Inventory.MaterialExternalSkuTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_material(opts) do
    base = %{
      name: opts[:name] || "Test Material #{System.unique_integer([:positive])}",
      sku: opts[:sku] || "MAT-#{System.unique_integer([:positive])}",
      unit: :gram,
      price: Decimal.new("1.00"),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    }

    attrs =
      case Map.fetch(opts, :external_sku) do
        {:ok, v} -> Map.put(base, :external_sku, v)
        :error -> base
      end

    Material
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(actor: staff())
  end

  describe "external_sku" do
    test "is optional on create" do
      assert {:ok, m} = create_material(%{})
      assert is_nil(m.external_sku)
    end

    test "accepts a supplier code" do
      assert {:ok, m} = create_material(%{external_sku: "IGF-34998"})
      assert m.external_sku == "IGF-34998"
    end

    test "is unique across non-nil values" do
      assert {:ok, _} = create_material(%{external_sku: "IGF-DUPLICATE"})
      assert {:error, _} = create_material(%{external_sku: "IGF-DUPLICATE"})
    end

    test "allows multiple materials with no external_sku (nils distinct)" do
      assert {:ok, _} = create_material(%{external_sku: nil})
      assert {:ok, _} = create_material(%{external_sku: nil})
    end
  end
end
