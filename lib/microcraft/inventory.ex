defmodule Microcraft.Warehouse do
  use Ash.Domain

  resources do
    resource Microcraft.Warehouse.Material
    resource Microcraft.Warehouse.Movement
  end
end
