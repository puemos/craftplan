defmodule MicrocraftWeb.Components do
  @moduledoc """
  Provides a unified interface for importing all UI components.

  This module re-exports components from specialized modules:
  - MicrocraftWeb.CoreComponents
  - MicrocraftWeb.FormComponents
  - MicrocraftWeb.NavigationComponents
  - MicrocraftWeb.DataDisplayComponents
  - MicrocraftWeb.ModalComponents
  """

  defmacro __using__(_opts) do
    quote do
      import MicrocraftWeb.Components.Core
      import MicrocraftWeb.Components.DataVis
      import MicrocraftWeb.Components.Forms

      # import MicrocraftWeb.Components.Modal
      # import MicrocraftWeb.Components.Navigation
    end
  end
end
