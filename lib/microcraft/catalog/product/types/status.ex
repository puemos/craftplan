defmodule Microcraft.Catalog.Product.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:idea, :experiment, :for_sale, :archived]
end
