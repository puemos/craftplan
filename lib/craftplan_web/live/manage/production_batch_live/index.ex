defmodule CraftplanWeb.ProductionBatchLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:batches, [])
     |> assign(:page_title, "Batches")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load_batches(socket)}
  end

  defp load_batches(socket) do
    actor = socket.assigns[:current_user]

    batches = Production.list_recent_batches(20, actor: actor)

    socket
    |> assign(:batches, batches)
    |> Navigation.assign(:production, [
      Navigation.root(:production),
      Navigation.page(:production, :batches)
    ])
  end

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Production Batches
        <:subtitle>
          Latest completed batches with cost breakdowns and lot links.
        </:subtitle>
        <:actions>
          <.button variant={:outline} phx-click="refresh">
            Refresh
          </.button>
        </:actions>
      </.header>

      <Page.section class="mt-6">
        <Page.surface>
          <.table id="batches-table" rows={@batches}>
            <:empty>
              <div class="rounded border border-dashed border-stone-200 bg-stone-50 py-8 text-center text-sm text-stone-500">
                No batches recorded yet. Mark production as completed in the planner to capture batches.
              </div>
            </:empty>
            <:col :let={batch} label="Batch">
              <.link navigate={~p"/manage/production/batches/#{batch.batch_code}"}>
                <.kbd>{batch.batch_code}</.kbd>
              </.link>
            </:col>
            <:col :let={batch} label="Product">
              {(batch.product && batch.product.name) || "—"}
            </:col>
            <:col :let={batch} label="Produced">
              {format_batch_time(batch.produced_at, @time_zone)}
            </:col>
            <:col :let={batch} label="Quantity">
              {(batch.totals && Decimal.to_string(batch.totals.quantity || Decimal.new(0))) || "0"}
            </:col>
            <:col :let={batch} label="Unit Cost">
              {format_money(
                @settings.currency,
                (batch.totals && batch.totals.unit_cost) || Decimal.new(0)
              )}
            </:col>
            <:col :let={batch} label="Orders">
              {batch.order_count}
            </:col>
            <:action :let={batch}>
              <.link navigate={~p"/manage/production/batches/#{batch.batch_code}"}>
                <.button size={:sm} variant={:outline}>View</.button>
              </.link>
            </:action>
          </.table>
        </Page.surface>
      </Page.section>
    </Page.page>
    """
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_batches(socket)}
  end

  defp format_batch_time(nil, _tz), do: "—"

  defp format_batch_time(datetime, tz) do
    format_time(datetime, tz)
  end
end
