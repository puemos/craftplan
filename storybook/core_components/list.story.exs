defmodule Storybook.CoreComponents.List do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  def function, do: &MicrocraftWeb.CoreComponents.list/1

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          ~s|<:item title="Title">Elixir</:item>|,
          ~s|<:item title="Rating">5/5</:item>|
        ]
      }
    ]
  end
end
