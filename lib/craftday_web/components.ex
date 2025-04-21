defmodule CraftdayWeb.Components do
  @moduledoc """
  Provides a unified interface for importing all UI components.

  This module re-exports components from specialized modules:
  - CraftdayWeb.CoreComponents
  - CraftdayWeb.FormComponents
  - CraftdayWeb.NavigationComponents
  - CraftdayWeb.DataDisplayComponents
  - CraftdayWeb.ModalComponents
  """

  defmacro __using__(_opts) do
    quote do
      import CraftdayWeb.Components.Core
      import CraftdayWeb.Components.DataVis
      import CraftdayWeb.Components.Forms

      # import CraftdayWeb.Components.Modal
      # import CraftdayWeb.Components.Navigation
    end
  end
end
