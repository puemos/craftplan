defmodule Craftplan.Catalog.ProductNameValidationTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog.Product

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_product(name) do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: "SKU-#{System.unique_integer([:positive])}",
      price: Decimal.new("10.00"),
      status: :active
    })
    |> Ash.create(actor: staff())
  end

  describe "product name regex validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_product("Test Product")
    end

    test "accepts ASCII with hyphens and dots" do
      assert {:ok, _} = create_product("Product-Name.v2")
    end

    test "accepts Japanese katakana" do
      assert {:ok, _} = create_product("チョコレートケーキ")
    end

    test "accepts Japanese hiragana" do
      assert {:ok, _} = create_product("さくらもち")
    end

    test "accepts Japanese kanji" do
      assert {:ok, _} = create_product("抹茶大福")
    end

    test "accepts mixed ASCII and Japanese" do
      assert {:ok, _} = create_product("チョコ Cake v2")
    end

    test "accepts Japanese middle dot (・)" do
      assert {:ok, _} = create_product("テスト・ケーキ")
    end

    test "accepts Japanese parentheses （）" do
      assert {:ok, _} = create_product("テスト（特別）")
    end

    test "accepts Japanese brackets 「」" do
      assert {:ok, _} = create_product("テスト「特別」")
    end

    test "rejects @ character" do
      assert {:error, changeset} = create_product("Test@Product")
      assert inspect(changeset.errors) =~ "must match"
    end

    test "rejects # character" do
      assert {:error, changeset} = create_product("Test#Product")
      assert inspect(changeset.errors) =~ "must match"
    end

    test "rejects name shorter than min length" do
      assert {:error, _} = create_product("A")
    end

    test "rejects name exceeding max length" do
      long_name = String.duplicate("a", 101)
      assert {:error, _} = create_product(long_name)
    end
  end
end
