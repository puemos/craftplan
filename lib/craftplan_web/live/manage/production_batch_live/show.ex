defmodule CraftplanWeb.ProductionBatchLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:batch_report, nil)
     |> assign(:page_title, "Batch")
     |> assign(:orders, [])
     |> assign(:lots, [])
     |> assign(:materials, [])
     |> assign(:totals, nil)
     |> assign(:product, nil)
     |> assign(:produced_at, nil)}
  end

  @impl true
  def handle_params(%{"batch_code" => batch_code}, _url, socket) do
    actor = socket.assigns[:current_user]

    report = Production.batch_report!(batch_code, actor: actor)

    socket =
      socket
      |> assign(:batch_report, report)
      |> assign(:batch_code, batch_code)
      |> assign(:product, report.product)
      |> assign(:bom, report.bom)
      |> assign(:orders, report.orders)
      |> assign(:lots, report.lots)
      |> assign(:materials, report.materials)
      |> assign(:totals, report.totals)
      |> assign(:produced_at, report.produced_at)
      |> assign(:production_batch, report.production_batch)
      |> assign(:page_title, "Batch #{batch_code}")
      |> Navigation.assign(:production, [
        Navigation.root(:production),
        Navigation.page(:production, :batches),
        Navigation.page(:production, :batch, %{batch_code: batch_code})
      ])

    {:noreply, socket}
  rescue
    _ ->
      {:noreply,
       socket
       |> put_flash(:error, "Batch not found")
       |> push_navigate(to: ~p"/manage/overview")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Batch {@batch_code}
        <:subtitle>
          {@product && @product.name}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/manage/overview"}>
            <.button variant={:outline}>Back to planner</.button>
          </.link>
          <.button variant={:primary} phx-click={JS.exec("window.print()")} class="print:hidden">
            Print Batch Sheet
          </.button>
        </:actions>
      </.header>

      <section id="batch-summary">
        <Page.section class="mt-6">
          <Page.surface>
            <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              <.summary_card label="Product" value={@product && @product.name}>
                <div class="text-xs text-stone-500">{@product && @product.sku}</div>
              </.summary_card>
              <.summary_card label="Produced" value={format_quantity(@totals)}>
                <div class="text-xs text-stone-500">Total units in this batch</div>
              </.summary_card>
              <.summary_card label="Produced At" value={format_batch_time(@produced_at, @time_zone)}>
                <div class="text-xs text-stone-500">Captured from completion events</div>
              </.summary_card>
              <.summary_card
                label="Average Unit Cost"
                value={
                  format_money(@settings.currency, (@totals && @totals.unit_cost) || Decimal.new(0))
                }
              >
                <div class="text-xs text-stone-500">Material + labor + overhead</div>
              </.summary_card>
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-3">
              <.cost_chip
                label="Material Cost"
                amount={(@totals && @totals.material_cost) || Decimal.new(0)}
                currency={@settings.currency}
              />
              <.cost_chip
                label="Labor Cost"
                amount={(@totals && @totals.labor_cost) || Decimal.new(0)}
                currency={@settings.currency}
              />
              <.cost_chip
                label="Overhead Cost"
                amount={(@totals && @totals.overhead_cost) || Decimal.new(0)}
                currency={@settings.currency}
              />
            </div>
          </Page.surface>
        </Page.section>
      </section>

      <section id="batch-orders">
        <Page.section class="mt-6">
          <Page.surface>
            <.table id="batch-orders-table" rows={@orders}>
              <:col :let={row} label="Order">
                <.link navigate={~p"/manage/orders/#{row.order.reference}"}>
                  <.kbd>{format_reference(row.order.reference)}</.kbd>
                </.link>
              </:col>
              <:col :let={row} label="Customer">
                {row.customer_name || "—"}
              </:col>
              <:col :let={row} label="Quantity">
                {row.quantity}
              </:col>
              <:col :let={row} label="Status">
                <.badge text={row.status} />
              </:col>
              <:col :let={row} label="Line Total">
                {format_money(@settings.currency, row.line_total)}
              </:col>
              <:col :let={row} label="Unit Cost">
                {format_money(@settings.currency, row.unit_cost)}
              </:col>
            </.table>
          </Page.surface>
        </Page.section>
      </section>

      <section id="batch-material-lots">
        <Page.section class="mt-6">
          <Page.surface>
            <div class="mb-4 flex items-center justify-between">
              <div>
                <h3 class="text-base font-semibold text-stone-900">Material Lots</h3>
                <p class="text-sm text-stone-500">
                  Lot allocations across every order item in this batch.
                </p>
              </div>
              <span class="text-sm text-stone-500">
                {@lots |> length()} lots
              </span>
            </div>

            <.table :if={Enum.any?(@lots)} id="batch-lots-table" rows={@lots}>
              <:col :let={lot} label="Material">
                {(lot.material && lot.material.name) || "Unknown"}
              </:col>
              <:col :let={lot} label="Lot Code">
                <div class="font-mono text-xs">{lot.lot_code}</div>
                <div class="text-xs text-stone-500">
                  Expires {format_short_date(lot.expiry_date, format: "%b %d, %Y", missing: "—")}
                </div>
              </:col>
              <:col :let={lot} label="Supplier">
                {(lot.supplier && lot.supplier.name) || "—"}
              </:col>
              <:col :let={lot} label="Used">
                {format_amount(lot.material && lot.material.unit, lot.quantity_used)}
              </:col>
              <:col :let={lot} label="Remaining">
                {format_amount(lot.material && lot.material.unit, lot.remaining)}
              </:col>
              <:col :let={lot} label="Orders">
                <div class="space-y-1">
                  <div :for={entry <- lot.orders} class="text-xs text-stone-600">
                    <.kbd>{format_reference(entry.reference)}</.kbd>
                    — {format_amount(lot.material && lot.material.unit, entry.quantity)}
                  </div>
                </div>
              </:col>
            </.table>

            <div
              :if={!Enum.any?(@lots)}
              class="rounded border border-dashed border-stone-200 bg-stone-50 p-6 text-center text-sm text-stone-500"
            >
              No lot allocations were recorded for this batch.
            </div>

            <div :if={Enum.any?(@materials)} class="mt-6 grid gap-4 md:grid-cols-3">
              <div :for={material <- @materials} class="rounded border border-stone-200 bg-white p-4">
                <p class="text-xs uppercase tracking-wide text-stone-500">
                  {(material.material && material.material.name) || "Material"}
                </p>
                <p class="mt-2 text-lg font-semibold text-stone-900">
                  {format_amount(material.material && material.material.unit, material.quantity_used)}
                </p>
                <p class="text-xs text-stone-500">
                  Lots:
                  <span
                    :for={lot <- material.lots}
                    class="text-[11px] mr-2 inline-flex gap-1 text-stone-600"
                  >
                    <.kbd>{lot.lot_code}</.kbd>
                    {format_amount(material.material && material.material.unit, lot.quantity_used)}
                  </span>
                </p>
              </div>
            </div>
          </Page.surface>
        </Page.section>
      </section>

      <Page.section class="mt-6">
        <div id="batch-compliance">
          <Page.surface padding="p-6">
            <div class="mb-4">
              <h3 class="text-base font-semibold text-stone-900">Compliance Notes</h3>
              <p class="text-sm text-stone-500">
                Capture operator sign-off and observations for printable records.
              </p>
            </div>

            <div class="space-y-4">
              <div>
                <p class="text-xs uppercase tracking-wide text-stone-500">Operator</p>
                <div class="min-h-[2rem] mt-1 rounded border border-dashed border-stone-300 px-3 py-2 text-sm text-stone-700">
                  ______________________________________
                </div>
              </div>

              <div>
                <p class="text-xs uppercase tracking-wide text-stone-500">Observations</p>
                <div class="min-h-[5rem] mt-1 rounded border border-dashed border-stone-300 px-3 py-2 text-sm text-stone-700">
                  {(@bom && @bom.notes) || "Add process notes or deviations before printing."}
                </div>
              </div>
            </div>
          </Page.surface>
        </div>
      </Page.section>
    </Page.page>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  slot :inner_block, required: false

  defp summary_card(assigns) do
    ~H"""
    <div class="rounded border border-stone-200 bg-white p-4">
      <p class="text-xs uppercase tracking-wide text-stone-500">{@label}</p>
      <p class="mt-2 text-xl font-semibold text-stone-900">{@value || "—"}</p>
      <div class="mt-1 text-xs text-stone-500">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :amount, :any, required: true
  attr :currency, :atom, required: true

  defp cost_chip(assigns) do
    ~H"""
    <div class="rounded border border-stone-200 bg-stone-50 px-4 py-3">
      <p class="text-xs uppercase tracking-wide text-stone-500">{@label}</p>
      <p class="mt-1 text-lg font-semibold text-stone-900">
        {format_money(@currency, @amount)}
      </p>
    </div>
    """
  end

  defp format_quantity(nil), do: "—"

  defp format_quantity(%{quantity: qty}) do
    Decimal.to_string(qty || Decimal.new(0))
  end

  defp format_batch_time(nil, _tz), do: "—"

  defp format_batch_time(datetime, tz) do
    format_time(datetime, tz)
  end
end
