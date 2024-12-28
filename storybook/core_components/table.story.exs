defmodule Storybook.CoreComponents.Table do
  use PhoenixStorybook.Story, :component
  alias MicrocraftWeb.CoreComponents

  def function, do: &CoreComponents.table/1
  def aliases, do: [Storybook.CoreComponents.Table.User]

  def variations do
    [
      %Variation{
        id: :table,
        attributes: %{
          rows:
            {:eval,
             ~s"""
             [
               %User{id: 1, username: "jose"},
               %User{id: 2, username: "chris"}
             ]
             """}
        },
        slots: [
          """
          <:col :let={user} label="Id">
            <%= user.id %>
          </:col>
          """,
          """
          <:col :let={user} label="User name">
            <%= user.username %>
          </:col>
          """
        ]
      }
    ]
  end
end

defmodule Storybook.CoreComponents.Table.User do
  defstruct [:id, :username]
end
