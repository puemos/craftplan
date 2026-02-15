defmodule CraftplanWeb.ProductionBatchLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Ash.Error.Invalid
  alias Craftplan.Orders
  alias Craftplan.Production
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation
  alias Decimal, as: D

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
     |> assign(:produced_at, nil)
     |> assign(:show_advanced_lots, false)
     |> assign(:consume_materials, [])
     |> assign(:allocations_for_complete, [])
     |> assign(:complete_payload, %{
       "produced_qty" => "",
       "duration_minutes" => ""
     })}
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
      |> assign(:consume_materials, build_consume_materials(report.production_batch, actor))
      |> assign(
        :allocations_for_complete,
        build_allocations_for_complete(report.production_batch, actor)
      )
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
          <.link href={~p"/manage/production/batches/#{@batch_code}/sheet.pdf"} target="_blank">
            <.button variant={:primary}>Print Batch Sheet</.button>
          </.link>
        </:actions>
      </.header>

      <section id="batch-summary">
        <Page.section class="mt-6">
          <Page.surface>
            <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              <.summary_card label="Product" value={@product && @product.name}>
                <div class="text-xs text-stone-500">{@product && @product.sku}</div>
              </.summary_card>
              <.summary_card
                label="Status"
                value={@production_batch && to_string(@production_batch.status)}
              >
                <div class="text-xs text-stone-500">Batch status at a glance</div>
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
                  format_money(
                    @settings.currency,
                    (@totals && @totals.unit_cost) || Money.new(0, :USD)
                  )
                }
              >
                <div class="text-xs text-stone-500">Material + labor + overhead</div>
              </.summary_card>
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-3">
              <.cost_chip
                label="Material Cost"
                amount={(@totals && @totals.material_cost) || Money.new(0, :USD)}
                currency={@settings.currency}
              />
              <.cost_chip
                label="Labor Cost"
                amount={(@totals && @totals.labor_cost) || Money.new(0, :USD)}
                currency={@settings.currency}
              />
              <.cost_chip
                label="Overhead Cost"
                amount={(@totals && @totals.overhead_cost) || Decimal.new(0)}
                currency={@settings.currency}
              />
            </div>
            <div class="mt-6 flex flex-wrap gap-2">
              <.button
                :if={@production_batch && @production_batch.status == :open}
                variant={:outline}
                phx-click="start_batch"
              >
                Start Batch
              </.button>
            </div>
          </Page.surface>
        </Page.section>
      </section>

      <section
        :if={@production_batch && @production_batch.status == :in_progress}
        id="complete-batch-section"
        class="mt-6"
      >
        <Page.section>
          <Page.surface>
            <h3 class="mb-4 text-base font-semibold text-stone-900">Complete Batch</h3>
            <p class="mb-4 text-sm text-stone-500">
              Enter produced quantity and optionally adjust lot allocations. Materials will be automatically consumed using FIFO (earliest expiry first) unless you override with manual lot selection.
            </p>
            <.form for={%{}} id="complete-batch-form" phx-submit="complete_batch">
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  type="number"
                  name="produced_qty"
                  label="Produced Quantity"
                  min="0"
                  step="any"
                  required
                  value={@complete_payload["produced_qty"]}
                />
                <.input
                  type="number"
                  name="duration_minutes"
                  label="Duration (minutes)"
                  min="0"
                  step="any"
                  value={@complete_payload["duration_minutes"]}
                />
              </div>

              <div :if={@allocations_for_complete != []} class="mt-4">
                <h4 class="mb-2 text-sm font-semibold text-stone-800">
                  Completed quantities per order item
                </h4>
                <div
                  :for={alloc <- @allocations_for_complete}
                  class="mb-2 flex items-center gap-3 rounded border border-stone-200 bg-stone-50 px-3 py-2"
                >
                  <div class="flex-1 text-sm">
                    <span class="font-mono text-xs">{alloc.order_reference}</span>
                    <span class="ml-2 text-stone-600">{alloc.product_name}</span>
                    <span class="ml-2 text-xs text-stone-400">
                      planned: {D.to_string(alloc.planned_qty)}
                    </span>
                  </div>
                  <.input
                    type="number"
                    name={"completed_map[#{alloc.order_item_id}]"}
                    value={D.to_string(alloc.planned_qty)}
                    min="0"
                    step="any"
                    class="w-24"
                  />
                </div>
              </div>

              <div class="mt-4">
                <label class="flex cursor-pointer items-center gap-2 text-sm text-stone-700">
                  <input
                    type="checkbox"
                    phx-click="toggle_advanced_lots"
                    checked={@show_advanced_lots}
                    class="rounded border-stone-300 text-stone-600 focus:ring-stone-500"
                  />
                  <span>Advanced: Manual Lot Selection</span>
                </label>
              </div>

              <div :if={@show_advanced_lots} class="mt-4">
                <div
                  :if={@consume_materials == []}
                  class="py-4 text-sm text-stone-500"
                >
                  No materials with available lots found for this batch.
                </div>
                <div :for={mat <- @consume_materials} class="mb-6">
                  <div class="mb-2 flex items-baseline justify-between">
                    <h4 class="text-sm font-semibold text-stone-800">{mat.name}</h4>
                    <span class="text-xs text-stone-500">
                      Required: {D.to_string(mat.required_qty)} per unit
                    </span>
                  </div>
                  <div
                    :for={lot <- mat.lots}
                    class="mb-2 flex items-center gap-3 rounded border border-stone-200 bg-stone-50 px-3 py-2"
                  >
                    <div class="flex-1 text-sm">
                      <span class="font-mono text-xs">{lot.lot_code}</span>
                      <span class="ml-2 text-stone-500">
                        stock: {D.to_string(lot.current_stock)}
                      </span>
                      <span :if={lot.expiry_date} class="ml-2 text-xs text-stone-400">
                        exp: {format_short_date(lot.expiry_date, format: "%b %d, %Y", missing: "—")}
                      </span>
                    </div>
                    <.input
                      type="number"
                      name={"lot_plan[#{mat.material_id}][#{lot.lot_id}]"}
                      value=""
                      min="0"
                      step="any"
                      placeholder="0"
                      class="w-24"
                    />
                  </div>
                </div>
              </div>

              <div class="mt-4 flex justify-end">
                <.button variant={:primary} type="submit">Complete Batch</.button>
              </div>
            </.form>
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

  @impl true
  def handle_event("start_batch", _params, socket) do
    actor = socket.assigns[:current_user]
    batch = socket.assigns.production_batch

    case Orders.start_batch(batch, %{}, actor: actor) do
      {:ok, _} -> refresh_and_flash(socket, "Batch started")
      {:error, err} -> {:noreply, put_flash(socket, :error, "Start failed: #{inspect(err)}")}
    end
  end

  @impl true
  def handle_event("toggle_advanced_lots", _params, socket) do
    {:noreply, assign(socket, show_advanced_lots: !socket.assigns.show_advanced_lots)}
  end

  @impl true
  def handle_event("complete_batch", %{"produced_qty" => produced_qty} = params, socket) do
    actor = socket.assigns[:current_user]
    batch = socket.assigns.production_batch
    duration = Map.get(params, "duration_minutes", "")
    completed_map = parse_completed_map(params)
    lot_plan = if socket.assigns.show_advanced_lots, do: parse_lot_plan(params)

    case parse_decimal(produced_qty) do
      {:ok, qty} ->
        complete_params =
          maybe_put_duration(
            %{produced_qty: qty, completed_map: completed_map, lot_plan: lot_plan},
            duration
          )

        case Orders.complete_batch(batch, complete_params, actor: actor) do
          {:ok, _} ->
            refresh_and_flash(socket, "Batch completed")

          {:error, %Invalid{} = err} ->
            if insufficient_stock_error?(err) do
              {:noreply,
               socket
               |> assign(show_advanced_lots: true)
               |> put_flash(:error, format_stock_error(err))}
            else
              {:noreply, put_flash(socket, :error, "Complete failed: #{inspect(err)}")}
            end

          {:error, err} ->
            {:noreply, put_flash(socket, :error, "Complete failed: #{inspect(err)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid completion payload")}
    end
  end

  defp insufficient_stock_error?(%Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :lot_plan} -> true
      %{message: msg} when is_binary(msg) -> String.contains?(msg, "Insufficient stock")
      _ -> false
    end)
  end

  defp insufficient_stock_error?(_), do: false

  defp format_stock_error(%Invalid{errors: errors}) do
    case Enum.find(errors, &match?(%{field: :lot_plan}, &1)) do
      %{message: msg, vars: vars} when is_map(vars) ->
        msg
        |> String.replace("%{material_id}", Map.get(vars, :material_id, "unknown"))
        |> String.replace("%{required}", Map.get(vars, :required, "?"))
        |> String.replace("%{short}", Map.get(vars, :short, "?"))

      _ ->
        "Insufficient stock. Use manual lot selection."
    end
  end

  defp parse_decimal(value) when is_binary(value) and value != "" do
    {:ok, D.new(value)}
  rescue
    _ -> {:error, :invalid_decimal}
  end

  defp parse_decimal(_), do: {:error, :invalid_decimal}

  defp maybe_put_duration(params, duration) when duration in [nil, ""], do: params

  defp maybe_put_duration(params, duration) do
    case parse_decimal(duration) do
      {:ok, d} -> Map.put(params, :duration_minutes, d)
      _ -> params
    end
  end

  defp refresh_and_flash(socket, message) do
    actor = socket.assigns[:current_user]
    report = Production.batch_report!(socket.assigns.batch_code, actor: actor)

    socket =
      socket
      |> assign(:batch_report, report)
      |> assign(:orders, report.orders)
      |> assign(:lots, report.lots)
      |> assign(:materials, report.materials)
      |> assign(:totals, report.totals)
      |> assign(:product, report.product)
      |> assign(:produced_at, report.produced_at)
      |> assign(:production_batch, report.production_batch)
      |> assign(:consume_materials, build_consume_materials(report.production_batch, actor))
      |> assign(
        :allocations_for_complete,
        build_allocations_for_complete(report.production_batch, actor)
      )

    {:noreply, put_flash(socket, :info, message)}
  end

  defp build_consume_materials(nil, _actor), do: []

  defp build_consume_materials(batch, actor) do
    components_map = batch.components_map || %{}

    if map_size(components_map) == 0 do
      []
    else
      components_map
      |> Enum.map(fn {material_id, per_unit_str} ->
        material =
          Craftplan.Inventory.get_material_by_id!(material_id, actor: actor)

        lots =
          %{material_id: material_id}
          |> Craftplan.Inventory.list_available_lots_for_material!(actor: actor)
          |> Enum.map(fn lot ->
            %{
              lot_id: lot.id,
              lot_code: lot.lot_code,
              current_stock: lot.current_stock,
              expiry_date: lot.expiry_date
            }
          end)

        %{
          material_id: material_id,
          name: material.name,
          required_qty: D.new(per_unit_str),
          lots: lots
        }
      end)
      |> Enum.sort_by(& &1.name)
    end
  rescue
    _ -> []
  end

  defp build_allocations_for_complete(nil, _actor), do: []

  defp build_allocations_for_complete(batch, actor) do
    %{production_batch_id: batch.id}
    |> Orders.list_allocations_for_batch!(actor: actor)
    |> Enum.map(fn alloc ->
      %{
        order_item_id: alloc.order_item_id,
        planned_qty: alloc.planned_qty,
        order_reference: alloc.order_item.order.reference,
        product_name: alloc.order_item.product.name
      }
    end)
    |> Enum.sort_by(& &1.order_reference)
  rescue
    _ -> []
  end

  defp parse_lot_plan(%{"lot_plan" => lot_plan_params}) when is_map(lot_plan_params) do
    lot_plan_params
    |> Map.new(fn {material_id, lots_map} ->
      entries =
        lots_map
        |> Enum.reject(fn {_lot_id, qty_str} -> qty_str in ["", "0", nil] end)
        |> Enum.map(fn {lot_id, qty_str} ->
          %{lot_id: lot_id, quantity: D.new(qty_str)}
        end)

      {material_id, entries}
    end)
    |> Enum.reject(fn {_k, v} -> v == [] end)
    |> Map.new()
  end

  defp parse_lot_plan(_), do: %{}

  defp parse_completed_map(%{"completed_map" => map}) when is_map(map) do
    Map.new(map, fn {order_item_id, qty_str} ->
      qty =
        case qty_str do
          "" -> D.new(0)
          s when is_binary(s) -> D.new(s)
          _ -> D.new(0)
        end

      {order_item_id, qty}
    end)
  end

  defp parse_completed_map(_), do: %{}

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
    D.to_string(qty || D.new(0))
  end

  defp format_batch_time(nil, _tz), do: "—"

  defp format_batch_time(datetime, tz) do
    format_time(datetime, tz)
  end
end
