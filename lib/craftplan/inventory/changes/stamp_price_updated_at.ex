defmodule Craftplan.Inventory.Changes.StampPriceUpdatedAt do
  @moduledoc """
  Stamp `Material.price_updated_at` to `now()` whenever `:price` is changing
  in the changeset. Runs before the write so the timestamp lands in the
  same row update as the price itself.
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    if Changeset.changing_attribute?(changeset, :price) do
      Changeset.force_change_attribute(changeset, :price_updated_at, DateTime.utc_now())
    else
      changeset
    end
  end
end
