defmodule CraftScale.Production do
  @moduledoc false
  use Ash.Domain

  resources do
    resource CraftScale.Production.Task
  end
end
