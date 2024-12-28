defmodule Storybook.CoreComponents.Flash do
  use PhoenixStorybook.Story, :component
  alias MicrocraftWeb.CoreComponents

  def function, do: &CoreComponents.flash/1
  def imports, do: [{CoreComponents, [button: 1, show: 1]}]

  def template do
    """
    <.button phx-click={show("#:variation_id")} psb-code-hidden>
      Open flash
    </.button>
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :info_no_title,
        attributes: %{
          kind: :info,
          hidden: true,
          title: "Flash title"
        },
        slots: ["Info message"]
      },
      %Variation{
        id: :error_with_title,
        attributes: %{
          kind: :error,
          hidden: true,
          title: "Flash title"
        },
        slots: ["Error message"]
      },
      %Variation{
        id: :no_close_button,
        attributes: %{
          kind: :info,
          hidden: true,
          close: false,
          title: "Flash title"
        },
        slots: ["Info message"]
      }
    ]
  end
end
