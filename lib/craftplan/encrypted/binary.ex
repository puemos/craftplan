defmodule Craftplan.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: Craftplan.Vault
end
