defmodule Craftplan.Inventory.Changes.PreventDestroyWithHistory do
  @moduledoc """
  Block Material destruction when the material has any inventory history
  (movements or lots) or is referenced by an active BOM. Without this,
  deletes pass straight to Postgres and surface as foreign-key violations
  in the logs while the UI only shows a generic "failed" flash.

  This change runs as a before_action so the destroy never reaches the DB
  when there's a real reason it shouldn't.
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.Movement

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn cs ->
      case cs.data do
        %{id: nil} ->
          cs

        %{id: material_id} ->
          counts = count_history(material_id)

          if any_history?(counts) do
            Changeset.add_error(cs,
              field: :base,
              message: format_message(counts)
            )
          else
            cs
          end
      end
    end)
  end

  defp count_history(material_id) do
    %{
      movements:
        Movement
        |> Ash.Query.filter(material_id == ^material_id)
        |> Ash.count!(authorize?: false),
      lots:
        Lot
        |> Ash.Query.filter(material_id == ^material_id)
        |> Ash.count!(authorize?: false)
    }
  end

  defp any_history?(%{movements: m, lots: l}), do: m > 0 or l > 0

  defp format_message(%{movements: m, lots: l}) do
    parts =
      [
        m > 0 && "#{m} inventory movement#{plural(m)}",
        l > 0 && "#{l} lot#{plural(l)}"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" and ")

    "Cannot delete: material has #{parts}. Materials with inventory history are kept " <>
      "to preserve the audit trail."
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
