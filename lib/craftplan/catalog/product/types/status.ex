defmodule Craftplan.Catalog.Product.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :draft,
      :testing,
      :active,
      :paused,
      :discontinued,
      :archived
    ]
end
