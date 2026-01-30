defmodule Craftplan.Accounts.ApiKeyTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Accounts

  defp create_api_key!(scopes \\ %{}, actor \\ admin_actor()) do
    {:ok, api_key} =
      Accounts.create_api_key(%{name: "test-key", scopes: scopes}, actor: actor)

    {Map.get(api_key, :__raw_key__), api_key}
  end

  describe "create" do
    test "admin can create an API key" do
      admin = admin_actor()

      {:ok, api_key} =
        Accounts.create_api_key(
          %{name: "My Key", scopes: %{"products" => ["read"]}},
          actor: admin
        )

      assert api_key.name == "My Key"
      assert api_key.scopes == %{"products" => ["read"]}
      assert api_key.user_id == admin.id
      assert is_nil(api_key.revoked_at)
      assert is_nil(api_key.last_used_at)
    end

    test "staff cannot create an API key" do
      staff = staff_actor()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.create_api_key(
                 %{name: "Staff Key", scopes: %{}},
                 actor: staff
               )
    end

    test "raw key is returned in __raw_key__" do
      {raw_key, _api_key} = create_api_key!()

      assert is_binary(raw_key)
      assert String.starts_with?(raw_key, "cpk_")
    end

    test "prefix is first 12 chars of raw key" do
      {raw_key, api_key} = create_api_key!()

      assert api_key.prefix == String.slice(raw_key, 0, 12)
    end

    test "key_hash is SHA-256 hex of raw key" do
      {raw_key, api_key} = create_api_key!()

      expected_hash =
        :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)

      assert api_key.key_hash == expected_hash
    end

    test "scopes map is stored correctly" do
      scopes = %{
        "products" => ["read", "write"],
        "orders" => ["read"],
        "customers" => ["read", "write"]
      }

      {_raw_key, api_key} = create_api_key!(scopes)

      assert api_key.scopes == scopes
    end
  end

  describe "authenticate" do
    test "lookup by key_hash succeeds for active key" do
      {raw_key, api_key} = create_api_key!(%{"products" => ["read"]})

      key_hash =
        :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)

      {:ok, found} =
        Accounts.authenticate_api_key(%{key_hash: key_hash},
          authorize?: false,
          not_found_error?: false
        )

      assert found.id == api_key.id
    end

    test "revoked key returns not found" do
      {raw_key, api_key} = create_api_key!(%{"products" => ["read"]})

      admin = admin_actor()
      {:ok, _revoked} = Accounts.revoke_api_key(api_key, actor: admin)

      key_hash =
        :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)

      assert {:ok, nil} =
               Accounts.authenticate_api_key(%{key_hash: key_hash},
                 not_found_error?: false
               )
    end

    test "non-existent hash returns not found" do
      fake_hash =
        :sha256
        |> :crypto.hash("cpk_nonexistent")
        |> Base.encode16(case: :lower)

      assert {:ok, nil} =
               Accounts.authenticate_api_key(%{key_hash: fake_hash},
                 not_found_error?: false
               )
    end
  end

  describe "revoke" do
    test "sets revoked_at" do
      {_raw_key, api_key} = create_api_key!()
      admin = admin_actor()

      assert is_nil(api_key.revoked_at)

      {:ok, revoked} = Accounts.revoke_api_key(api_key, actor: admin)

      assert revoked.revoked_at
    end

    test "revoked key is excluded from authenticate" do
      {raw_key, api_key} = create_api_key!()
      admin = admin_actor()

      {:ok, _revoked} = Accounts.revoke_api_key(api_key, actor: admin)

      key_hash =
        :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)

      assert {:ok, nil} =
               Accounts.authenticate_api_key(%{key_hash: key_hash},
                 not_found_error?: false
               )
    end
  end

  describe "list_for_user" do
    test "returns only keys for the given user_id" do
      admin1 = admin_actor()
      admin2 = admin_actor()

      {:ok, _key1} =
        Accounts.create_api_key(%{name: "key-1", scopes: %{}}, actor: admin1)

      {:ok, _key2} =
        Accounts.create_api_key(%{name: "key-2", scopes: %{}}, actor: admin2)

      {:ok, keys} =
        Accounts.list_api_keys_for_user(%{user_id: admin1.id}, actor: admin1)

      assert length(keys) == 1
      assert hd(keys).name == "key-1"
    end

    test "returns keys sorted by inserted_at desc" do
      admin = admin_actor()

      {:ok, _k1} =
        Accounts.create_api_key(%{name: "first", scopes: %{}}, actor: admin)

      {:ok, _k2} =
        Accounts.create_api_key(%{name: "second", scopes: %{}}, actor: admin)

      {:ok, keys} =
        Accounts.list_api_keys_for_user(%{user_id: admin.id}, actor: admin)

      assert length(keys) == 2
      # Most recent first
      assert hd(keys).name == "second"
    end
  end

  describe "touch_last_used" do
    test "sets last_used_at timestamp" do
      {_raw_key, api_key} = create_api_key!()

      assert is_nil(api_key.last_used_at)

      {:ok, touched} = Accounts.touch_api_key_last_used(api_key, authorize?: false)

      assert touched.last_used_at
    end
  end
end
