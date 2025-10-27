defmodule CraftplanWeb.NavigationTest do
  use ExUnit.Case, async: true

  alias CraftplanWeb.Navigation
  alias Phoenix.LiveView.Socket

  describe "breadcrumbs" do
    test "normalize maps with consistent keys" do
      order = %{reference: "ORD-001"}

      socket = %Socket{assigns: %{live_action: :show, __changed__: %{}}}

      socket =
        Navigation.assign(socket, :orders, [
          Navigation.root(:orders),
          Navigation.resource(:order, order)
        ])

      assert [first, second] = socket.assigns.breadcrumbs
      assert %{label: "Orders", path: "/manage/orders", current?: false} = first
      assert %{label: label, path: "/manage/orders/ORD-001", current?: true} = second
      assert label =~ "ORD"
    end
  end

  describe "nav sub links" do
    test "inventory links activate based on live action" do
      socket = %Socket{assigns: %{live_action: :show, __changed__: %{}}}

      socket = Navigation.assign(socket, :inventory, [Navigation.root(:inventory)])

      assert [%{label: "Materials", active: true} | _] = socket.assigns.nav_sub_links

      refute Enum.any?(socket.assigns.nav_sub_links, fn link ->
               link.label == "Usage Forecast" and link.active
             end)
    end

    test "production schedule honors schedule view" do
      socket = %Socket{assigns: %{live_action: :schedule, schedule_view: :week, __changed__: %{}}}

      socket = Navigation.assign(socket, :production, [Navigation.root(:production)])

      weekly = Enum.find(socket.assigns.nav_sub_links, &(&1.label == "Weekly"))
      daily = Enum.find(socket.assigns.nav_sub_links, &(&1.label == "Daily"))

      assert weekly.active
      refute daily.active
    end
  end
end
