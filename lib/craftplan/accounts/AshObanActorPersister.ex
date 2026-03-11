defmodule Craftplan.AshObanActorPersister do
  @moduledoc false
  use AshOban.ActorPersister

  def store(%Craftplan.Accounts.User{id: id}), do: %{"type" => "user", "id" => id}

  def lookup(%{"type" => "user", "id" => id}), do: Craftplan.Accounts.get_user_by_id(id, authorize?: false)

  # This allows you to set a default actor
  # in cases where no actor was present
  # when scheduling.
  def lookup(nil), do: {:ok, nil}
end
