defmodule Storybook.CoreComponents.Button do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  def function, do: &MicrocraftWeb.CoreComponents.button/1

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["Button"]
      },
      %Variation{
        id: :custom_class,
        attributes: %{
          class: "rounded-full bg-indigo-500 hover:bg-indigo-600"
        },
        slots: ["Disabled"]
      },
      %Variation{
        id: :disabled,
        attributes: %{
          disabled: true
        },
        slots: ["Disabled"]
      }
    ]
  end
end
