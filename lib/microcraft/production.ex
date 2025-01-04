defmodule Microcraft.Production do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Microcraft.Production.Task
  end
end
