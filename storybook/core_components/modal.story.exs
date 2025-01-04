defmodule Storybook.CoreComponents.Modal do
  @moduledoc false
  use PhoenixStorybook.Story, :component

  alias MicrocraftWeb.CoreComponents

  def function, do: &CoreComponents.modal/1
  def imports, do: [{CoreComponents, [button: 1, hide_modal: 1, show_modal: 1]}]

  def template do
    """
    <.button phx-click={show_modal(":variation_id")} psb-code-hidden>
      Open modal
    </.button>
    <.psb-variation/>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        slots: ["Modal body"]
      }
    ]
  end
end
