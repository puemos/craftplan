defmodule Craftplan.Repo.Seeds.SeedSupplier do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    params = [{"Fresh Dairy Ltd.", "sales@dairy.test"}, {"Miller & Co.", "hello@miller.test"}]

    Enum.each(params, fn {name, email} ->
      Craftplan.Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        contact_email: email
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
