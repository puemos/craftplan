defmodule CraftplanWeb.ManageInventoryReorderLiveTest do
  # async: false + shared sandbox — the page computes metrics in a start_async
  # task; shared mode guarantees that task can reach the test's DB connection.
  use CraftplanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Craftplan.Repo, {:shared, self()})
    :ok
  end

  describe "async metrics load" do
    @tag role: :staff
    test "mount returns immediately with the loading state, then resolves async", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/manage/inventory/forecast/reorder")

      # Mount did NOT block on the ~2s computation: spinner is shown.
      assert html =~ "Loading inventory metrics"

      # Awaiting the async assign clears the spinner and renders the band
      # (empty state is fine with no seeded data).
      resolved = render_async(view)
      refute resolved =~ "Loading inventory metrics"
      assert resolved =~ "No forecast rows available" or resolved =~ "owner-metrics-band"
    end

    @tag role: :staff
    test "changing the horizon recomputes asynchronously (no blocking)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/inventory/forecast/reorder")
      render_async(view)

      clicked =
        view
        |> element(~s(button[phx-click="set_horizon"][phx-value-days="28"]))
        |> render_click()

      # The toggle handler returned without blocking on the recompute:
      # the spinner is shown again.
      assert clicked =~ "Loading inventory metrics"

      resolved = render_async(view)
      refute resolved =~ "Loading inventory metrics"
    end
  end
end
