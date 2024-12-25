defmodule Microcraft.Production do
  use Ash.Domain

  resources do
    resource Microcraft.Production.Task
  end
end
