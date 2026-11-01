defmodule CraftplanWeb.ProductionBatchLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Ash.Error.Invalid
  alias Craftplan.Orders
  alias Craftplan.Production
  alias Craftplan.Production.Batching
  alias Craftplan.Types.Unit
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
     |> assign(:suggested_lot_plan, nil)
     |> assign(:lot_preview_error, nil)
     |> assign(:materials_consumed?, false)
     |> assign(:consume_materials, [])
     |> assign(:allocations_for_complete, [])
     |> assign(:complete_form, empty_completion_form())}
  end

  @impl true
  def handle_params(%{"batch_code" => batch_code}, _url, socket) do
    actor = socket.assigns[:current_user]

    report = Production.batch_report!(batch_code, actor: actor)

    socket =
      socket
      |> assign(:complete_form, empty_completion_form())
      |> assign(:show_advanced_lots, false)
      |> assign(:suggested_lot_plan, nil)
      |> assign(:lot_preview_error, nil)
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
      |> assign(:materials_consumed?, report.lots != [])
      |> assign(:page_title, "Batch #{batch_code}")
      |> assign(:consume_materials, build_consume_materials(report.production_batch, actor))
      |> assign(
        :allocations_for_complete,
        build_allocations_for_complete(report.production_batch, actor)
      )
      |> assign_completion_form(%{})
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
          <.link navigate={~p"/manage/production/traceability?#{%{mode: :backward, q: @batch_code}}"}>
            <.button id="trace-production-batch" variant={:outline}>
              <.icon name="hero-share" class="h-4 w-4" /> Trace Batch
            </.button>
          </.link>
          <.link navigate={~p"/manage/production/batches/#{@batch_code}/label"}>
            <.button id="print-product-label" variant={:outline}>Product Label</.button>
          </.link>
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
            <div class="mt-6 flex flex-wrap gap-2">
              <.button
                :if={@production_batch && @production_batch.status == :open}
                variant={:outline}
                phx-click="start_batch"
              >
                Start Batch
              </.button>
              <.button
                :if={@production_batch && @production_batch.status in [:open, :in_progress]}
                id="cancel-batch"
                variant={:outline}
                phx-click="cancel_batch"
                data-confirm="Cancel this batch? Its order quantities will be available to plan again."
              >
                Cancel Batch
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
            <.form
              for={@complete_form}
              id="complete-batch-form"
              phx-change="validate_completion"
              phx-submit="complete_batch"
            >
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  type="number"
                  field={@complete_form[:produced_qty]}
                  id="batch-produced-qty"
                  label="Produced Quantity"
                  min="0"
                  step="any"
                  phx-debounce="250"
                  required
                />
                <.input
                  type="number"
                  field={@complete_form[:duration_minutes]}
                  id="batch-duration-minutes"
                  label="Duration (minutes)"
                  min="0"
                  step="any"
                />
              </div>

              <div :if={@allocations_for_complete != []} class="mt-4">
                <h4 class="mb-2 text-sm font-semibold text-stone-800">
                  Completed quantities per order item
                </h4>
                <div
                  :for={alloc <- @allocations_for_complete}
                  class="mb-2 flex flex-col gap-3 rounded border border-stone-200 bg-stone-50 px-3 py-2 sm:flex-row sm:items-center"
                >
                  <div class="min-w-0 flex-1 text-sm">
                    <span class="font-mono text-xs">{alloc.order_reference}</span>
                    <span class="ml-2 text-stone-600">{alloc.product_name}</span>
                    <span class="ml-2 text-xs text-stone-400">
                      planned: {D.to_string(alloc.planned_qty)}
                    </span>
                  </div>
                  <div class="w-full shrink-0 sm:w-40">
                    <.input
                      type="number"
                      field={@completed_quantities_form[alloc.order_item_id]}
                      id={"completed-quantity-#{alloc.order_item_id}"}
                      label="Completed quantity"
                      aria-label={"Completed quantity for #{alloc.order_reference}"}
                      min="0"
                      step="any"
                    />
                  </div>
                </div>
              </div>

              <div id="lot-allocation-preview" class="mt-6" aria-live="polite">
                <h4 class="text-sm font-semibold text-stone-800">Suggested lot allocation</h4>
                <p class="mt-1 text-sm text-stone-500">
                  Earliest expiry first. Stock is checked again when you complete the batch.
                </p>
                <%= cond do %>
                  <% @materials_consumed? -> %>
                    <p class="mt-3 text-sm text-stone-600">
                      Materials have already been consumed. Recorded quantities are shown below.
                    </p>
                  <% @lot_preview_error -> %>
                    <p
                      id="lot-allocation-preview-error"
                      class="mt-3 text-sm text-rose-600"
                      role="alert"
                    >
                      {@lot_preview_error}
                    </p>
                  <% is_nil(@suggested_lot_plan) -> %>
                    <p class="mt-3 text-sm text-stone-500">
                      Enter a produced quantity greater than zero to preview the lots to pick.
                    </p>
                  <% @consume_materials == [] -> %>
                    <p class="mt-3 text-sm text-stone-500">This batch requires no material lots.</p>
                  <% true -> %>
                    <div
                      :for={material <- @consume_materials}
                      id={"suggested-material-#{material.material_id}"}
                      class="mt-4 rounded border border-stone-200 bg-stone-50 p-3"
                    >
                      <h5 class="text-sm font-semibold text-stone-800">{material.name}</h5>
                      <div
                        :for={lot <- suggested_lots(material, @suggested_lot_plan)}
                        id={"suggested-lot-#{lot.lot_id}"}
                        class="mt-2 flex items-baseline justify-between gap-3 text-sm"
                      >
                        <span class="font-mono min-w-0 break-all text-xs">{lot.lot_code}</span>
                        <span class="shrink-0">{format_lot_quantity(material.unit, lot.quantity)}</span>
                      </div>
                    </div>
                <% end %>
              </div>

              <div :if={!@materials_consumed?} class="mt-4">
                <label class="flex cursor-pointer items-center gap-2 text-sm text-stone-700">
                  <input
                    type="checkbox"
                    id="toggle-manual-lots"
                    phx-click="toggle_advanced_lots"
                    checked={@show_advanced_lots}
                    class="rounded border-stone-300 text-stone-600 focus:ring-stone-500"
                  />
                  <span>Advanced: Manual Lot Selection</span>
                </label>
              </div>

              <div
                :if={@show_advanced_lots && !@materials_consumed?}
                id="manual-lot-selection"
                class="mt-4"
              >
                <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                  <p class="text-sm text-stone-500">
                    Use the suggested quantities as a starting point, then adjust the lots to pick.
                  </p>
                  <.button
                    id="use-suggested-lots"
                    type="button"
                    variant={:outline}
                    phx-click="use_suggested_lots"
                    disabled={is_nil(@suggested_lot_plan) || @consume_materials == []}
                  >
                    Use suggested
                  </.button>
                </div>
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
                      Required: {format_lot_quantity(mat.unit, mat.required_qty)} per unit
                    </span>
                  </div>
                  <div
                    :for={lot <- mat.lots}
                    class="mb-2 flex flex-col gap-3 rounded border border-stone-200 bg-stone-50 px-3 py-2 sm:flex-row sm:items-center"
                  >
                    <div class="min-w-0 flex-1 text-sm">
                      <span class="font-mono break-all text-xs">{lot.lot_code}</span>
                      <span class="ml-2 text-stone-500">
                        stock: {format_lot_quantity(mat.unit, lot.current_stock)}
                      </span>
                      <span :if={lot.expiry_date} class="ml-2 text-xs text-stone-400">
                        exp: {format_short_date(lot.expiry_date, format: "%b %d, %Y", missing: "—")}
                      </span>
                    </div>
                    <div class="w-full shrink-0 sm:w-32">
                      <.input
                        type="number"
                        field={@manual_lot_forms[mat.material_id][lot.lot_id]}
                        id={"lot-quantity-#{lot.lot_id}"}
                        label={"Quantity (#{Unit.abbreviation(mat.unit)})"}
                        aria-label={"Quantity from #{lot.lot_code} (#{Unit.abbreviation(mat.unit)})"}
                        min="0"
                        step="any"
                        placeholder="0"
                      />
                    </div>
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
                <h3 class="text-base font-semibold text-stone-900">Consumed Material Lots</h3>
                <p class="text-sm text-stone-500">
                  Recorded material consumption for this batch.
                </p>
              </div>
              <span class="text-sm text-stone-500">
                {@lots |> length()} lots
              </span>
            </div>

            <.table
              :if={Enum.any?(@lots)}
              id="batch-lots-table"
              rows={@lots}
              row_id={&"consumed-lot-#{&1.lot.id}"}
            >
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
  def handle_event("cancel_batch", _params, socket) do
    case Orders.cancel_batch(socket.assigns.production_batch, %{}, actor: socket.assigns[:current_user]) do
      {:ok, _} ->
        refresh_and_flash(socket, "Batch canceled")

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Could not cancel batch. Only open or in-progress batches without recorded material consumption can be canceled."
         )}
    end
  end

  @impl true
  def handle_event("toggle_advanced_lots", _params, socket) do
    {:noreply, assign(socket, show_advanced_lots: !socket.assigns.show_advanced_lots)}
  end

  @impl true
  def handle_event("validate_completion", params, socket) do
    {:noreply, update_lot_suggestion(socket, params)}
  end

  @impl true
  def handle_event("use_suggested_lots", _params, socket) do
    socket = update_lot_suggestion(socket, %{})

    case socket.assigns.suggested_lot_plan do
      nil ->
        {:noreply, socket}

      plan ->
        lot_params =
          Map.new(plan, fn {material_id, entries} ->
            {material_id, Map.new(entries, &{&1.lot_id, D.to_string(&1.quantity, :normal)})}
          end)

        {:noreply, assign_completion_form(socket, %{"lot_plan" => lot_params})}
    end
  end

  @impl true
  def handle_event("complete_batch", %{"produced_qty" => produced_qty} = params, socket) do
    socket = update_lot_suggestion(socket, params)
    actor = socket.assigns[:current_user]
    batch = socket.assigns.production_batch
    duration = Map.get(params, "duration_minutes", "")

    with {:ok, qty} <- parse_decimal(produced_qty),
         {:ok, completed_map} <- parse_completed_map(params),
         {:ok, lot_plan} <- completion_lot_plan(params, socket.assigns.show_advanced_lots) do
      complete_params =
        maybe_put_duration(
          %{produced_qty: qty, completed_map: completed_map, lot_plan: lot_plan},
          duration
        )

      case Orders.complete_batch(batch, complete_params, actor: actor) do
        {:ok, _} ->
          refresh_and_flash(socket, "Batch completed")

        {:error, %Invalid{} = err} ->
          if lot_plan_error?(err) do
            {:noreply,
             socket
             |> assign(show_advanced_lots: true)
             |> put_flash(:error, format_lot_plan_error(err, socket.assigns.consume_materials))}
          else
            {:noreply, put_flash(socket, :error, "Complete failed: #{inspect(err)}")}
          end

        {:error, err} ->
          {:noreply, put_flash(socket, :error, "Complete failed: #{inspect(err)}")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid completion payload")}
    end
  end

  defp lot_plan_error?(%Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :lot_plan} -> true
      %{message: msg} when is_binary(msg) -> String.contains?(msg, "Insufficient stock")
      _ -> false
    end)
  end

  defp format_lot_plan_error(%Invalid{errors: errors}, materials) do
    case Enum.find(errors, &match?(%{field: :lot_plan}, &1)) do
      %{message: msg, vars: vars} when is_map(vars) or is_list(vars) ->
        vars =
          Map.update(Map.new(vars), :material_id, "unknown", fn id ->
            case Enum.find(materials, &(&1.material_id == id)) do
              nil -> id
              material -> material.name
            end
          end)

        Enum.reduce(vars, msg, fn {key, value}, message ->
          String.replace(message, "%{#{key}}", to_string(value))
        end)

      _ ->
        "Check the quantities in the manual lot selection."
    end
  end

  defp parse_decimal(value) when is_binary(value) and value != "" do
    case D.parse(value) do
      {%D{coef: coefficient} = decimal, ""} when is_integer(coefficient) -> {:ok, decimal}
      _ -> {:error, :invalid_decimal}
    end
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
      |> assign(:materials_consumed?, report.lots != [])
      |> assign(:consume_materials, build_consume_materials(report.production_batch, actor))
      |> assign(
        :allocations_for_complete,
        build_allocations_for_complete(report.production_batch, actor)
      )
      |> assign_completion_form(%{})

    {:noreply, socket |> clear_flash(:error) |> put_flash(:info, message)}
  end

  defp build_consume_materials(nil, _actor), do: []

  defp build_consume_materials(%{status: status}, _actor) when status != :in_progress, do: []

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
          |> Craftplan.Inventory.list_consumable_lots_for_material!(actor: actor)
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
          unit: material.unit,
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

  defp assign_completion_form(socket, params) do
    defaults =
      Map.new(
        socket.assigns.allocations_for_complete,
        &{&1.order_item_id, D.to_string(&1.planned_qty, :normal)}
      )

    params =
      socket.assigns.complete_form.params
      |> Map.merge(Map.take(params, ["produced_qty", "duration_minutes", "completed_map", "lot_plan"]))
      |> Map.put_new("completed_map", defaults)

    lot_params = map_param(params, "lot_plan")

    manual_lot_forms =
      Map.new(socket.assigns.consume_materials, fn material ->
        defaults = Map.new(material.lots, &{&1.lot_id, ""})
        values = Map.merge(defaults, map_param(lot_params, material.material_id))

        {material.material_id, to_form(values, as: "lot_plan[#{material.material_id}]")}
      end)

    assign(socket,
      complete_form: to_form(params),
      completed_quantities_form: to_form(map_param(params, "completed_map"), as: "completed_map"),
      manual_lot_forms: manual_lot_forms
    )
  end

  defp empty_completion_form do
    to_form(%{"produced_qty" => "", "duration_minutes" => ""})
  end

  defp map_param(params, key) do
    case Map.get(params, key) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp update_lot_suggestion(socket, params) do
    socket =
      socket
      |> assign(
        :consume_materials,
        build_consume_materials(socket.assigns.production_batch, socket.assigns.current_user)
      )
      |> assign_completion_form(params)

    result =
      with false <- socket.assigns.materials_consumed?,
           {:ok, quantity} <- parse_decimal(socket.assigns.complete_form[:produced_qty].value),
           true <- D.gt?(quantity, D.new(0)) do
        Batching.auto_select_lots(socket.assigns.production_batch, quantity)
      end

    case result do
      {:ok, plan} ->
        assign(socket, suggested_lot_plan: plan, lot_preview_error: nil)

      {:error, {:insufficient_stock, material_id, required, short}} ->
        material = Enum.find(socket.assigns.consume_materials, &(&1.material_id == material_id))

        message =
          "Insufficient stock for #{material.name}. Need #{format_lot_quantity(material.unit, required)}, short by #{format_lot_quantity(material.unit, short)}."

        assign(socket, suggested_lot_plan: nil, lot_preview_error: message)

      _ ->
        assign(socket, suggested_lot_plan: nil, lot_preview_error: nil)
    end
  end

  defp suggested_lots(material, plan) do
    lots_by_id = Map.new(material.lots, &{&1.lot_id, &1})

    Enum.map(Map.get(plan, material.material_id, []), fn entry ->
      lot = Map.get(lots_by_id, entry.lot_id, %{lot_code: entry.lot_id})
      Map.merge(lot, entry)
    end)
  end

  defp format_lot_quantity(unit, quantity) do
    "#{D.to_string(D.normalize(quantity), :normal)} #{Unit.abbreviation(unit)}"
  end

  defp completion_lot_plan(_params, false), do: {:ok, nil}

  defp completion_lot_plan(params, true) do
    params
    |> Map.get("lot_plan", %{})
    |> parse_lot_plan()
  end

  defp parse_lot_plan(lot_params) when is_map(lot_params) do
    Enum.reduce_while(lot_params, {:ok, %{}}, fn {material_id, lots}, {:ok, plan} ->
      case parse_quantities(lots) do
        {:ok, quantities} ->
          entries =
            quantities
            |> Enum.reject(fn {_id, quantity} -> D.equal?(quantity, D.new(0)) end)
            |> Enum.map(fn {lot_id, quantity} -> %{lot_id: lot_id, quantity: quantity} end)

          plan = if entries == [], do: plan, else: Map.put(plan, material_id, entries)
          {:cont, {:ok, plan}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp parse_lot_plan(_), do: {:error, :invalid_lot_plan}

  defp parse_completed_map(params), do: parse_quantities(Map.get(params, "completed_map", %{}))

  defp parse_quantities(params) when is_map(params) do
    Enum.reduce_while(params, {:ok, %{}}, fn {id, value}, {:ok, quantities} ->
      case parse_decimal(if value in [nil, ""], do: "0", else: value) do
        {:ok, quantity} -> {:cont, {:ok, Map.put(quantities, id, quantity)}}
        error -> {:halt, error}
      end
    end)
  end

  defp parse_quantities(_), do: {:error, :invalid_quantities}

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
