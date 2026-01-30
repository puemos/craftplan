defmodule Craftplan.Accounts.ApiKey.Changes.GenerateKey do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset

  @prefix "cpk_"

  @impl true
  def change(changeset, _opts, context) do
    raw_key = @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    key_hash = :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)
    prefix = String.slice(raw_key, 0, 12)

    changeset
    |> Changeset.force_change_attribute(:key_hash, key_hash)
    |> Changeset.force_change_attribute(:prefix, prefix)
    |> Changeset.force_change_attribute(:user_id, context.actor.id)
    |> Changeset.after_action(fn _changeset, api_key ->
      {:ok, Map.put(api_key, :__raw_key__, raw_key)}
    end)
  end
end
