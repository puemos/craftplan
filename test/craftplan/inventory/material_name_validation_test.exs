defmodule Craftplan.Inventory.MaterialNameValidationTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_material(name) do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: "MAT-#{System.unique_integer([:positive])}",
      unit: :gram,
      price: Decimal.new("1.00"),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create(actor: staff())
  end

  describe "material name regex validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_material("Flour")
    end

    test "accepts Japanese kanji" do
      assert {:ok, _} = create_material("小麦粉")
    end

    test "accepts Japanese katakana" do
      assert {:ok, _} = create_material("チョコレート")
    end

    test "accepts Japanese hiragana" do
      assert {:ok, _} = create_material("きなこ")
    end

    test "accepts Japanese middle dot (・)" do
      assert {:ok, _} = create_material("薄力粉・強力粉")
    end

    test "rejects @ character" do
      assert {:error, changeset} = create_material("Flour@Special")
      assert inspect(changeset.errors) =~ "must match"
    end
  end

  describe "material name max_length boundary" do
    test "accepts 255-character name" do
      name = String.duplicate("a", 255)
      assert {:ok, _} = create_material(name)
    end

    test "rejects 256-character name" do
      name = String.duplicate("a", 256)
      assert {:error, _} = create_material(name)
    end
  end

  describe "material name min_length" do
    test "rejects single character name" do
      assert {:error, _} = create_material("A")
    end
  end
end
