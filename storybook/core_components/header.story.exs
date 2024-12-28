defmodule Storybook.CoreComponents.Header do
  use PhoenixStorybook.Story, :component
  alias MicrocraftWeb.CoreComponents

  def function, do: &CoreComponents.header/1
  def imports, do: [{CoreComponents, button: 1}]

  def variations do
    [
      %Variation{
        id: :default,
        slots: [
          "Hello World"
        ]
      },
      %Variation{
        id: :with_a_subtitle,
        slots: [
          "Hello World",
          "<:subtitle>I'm a header subtitle</:subtitle>"
        ]
      },
      %Variation{
        id: :with_actions,
        slots: [
          "Hello World",
          "<:subtitle>I'm a header subtitle</:subtitle>",
          """
          <:actions>
            <.button>Link</.button>
          </:actions>
          """
        ]
      }
    ]
  end
end
