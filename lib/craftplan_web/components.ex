defmodule CraftplanWeb.Components do
  @moduledoc """
  Provides a unified interface for importing all UI components.

  This module re-exports components from specialized modules:
  - CraftplanWeb.CoreComponents
  - CraftplanWeb.FormComponents
  - CraftplanWeb.NavigationComponents
  - CraftplanWeb.DataDisplayComponents
  - CraftplanWeb.ModalComponents
  """

  defmacro __using__(_opts) do
    quote do
      import CraftplanWeb.Components.Core
      import CraftplanWeb.Components.DataVis
      import CraftplanWeb.Components.Forms
      import CraftplanWeb.Components.Page

      # import CraftplanWeb.Components.Modal
      # import CraftplanWeb.Components.Navigation
    end
  end
end
