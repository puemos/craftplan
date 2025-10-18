defmodule Craftplan.Test.AshHelpers do
  @moduledoc """
  Thin wrappers around Ash actions to consistently pass `actor` and optional loads.
  """

  def ash_create!(resource_or_record, action, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor, Craftplan.DataCase.staff_actor())

    resource_or_record
    |> Ash.Changeset.for_create(action, attrs)
    |> Ash.create!(actor: actor)
  end

  def ash_update!(record, action, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor, Craftplan.DataCase.staff_actor())

    record
    |> Ash.Changeset.for_update(action, attrs)
    |> Ash.update!(actor: actor)
  end

  def ash_read!(resource, action, args \\ %{}, opts \\ []) do
    actor = Keyword.get(opts, :actor, Craftplan.DataCase.staff_actor())
    load = Keyword.get(opts, :load, [])

    resource
    |> Ash.Query.for_read(action, args)
    |> Ash.Query.load(load)
    |> Ash.read!(actor: actor)
  end
end

