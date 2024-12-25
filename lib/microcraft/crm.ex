defmodule Microcraft.CRM do
  use Ash.Domain

  resources do
    resource Microcraft.CRM.Customer
  end
end
