defmodule Craftplan.CRM.CustomerNameValidationTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CRM.Customer

  defp create_customer(first_name, last_name) do
    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: first_name,
      last_name: last_name,
      email: "test+#{System.unique_integer([:positive])}@local"
    })
    |> Ash.create()
  end

  describe "customer first_name validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_customer("Jane", "Doe")
    end

    test "accepts Japanese first name" do
      assert {:ok, _} = create_customer("太郎", "田中")
    end

    test "accepts katakana first name" do
      assert {:ok, _} = create_customer("タロウ", "タナカ")
    end

    test "rejects invalid chars in first name" do
      assert {:error, changeset} = create_customer("Jane@", "Doe")
      assert inspect(changeset.errors) =~ "must match"
    end
  end

  describe "customer last_name validation" do
    test "rejects invalid chars in last name" do
      assert {:error, changeset} = create_customer("Jane", "Doe#")
      assert inspect(changeset.errors) =~ "must match"
    end
  end
end
