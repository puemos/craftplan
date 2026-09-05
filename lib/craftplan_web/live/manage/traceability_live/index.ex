defmodule CraftplanWeb.TraceabilityLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Ash.Changeset
  alias Craftplan.Production
  alias Craftplan.Traceability
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation
  alias Decimal, as: D

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(:page_title, "Trace Center")
     |> assign(:query, "")
     |> assign(:mode, :recall)
     |> assign(:form, to_form(%{"query" => ""}, as: :trace))
     |> assign(:searched?, false)
     |> assign(:result, %{lots: [], batches: []})
     |> assign(:recent_lots, Traceability.recent_lots(actor: actor, limit: 6))
     |> assign(:recent_batches, Production.list_recent_batches(6, actor: actor))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params |> Map.get("q", "") |> String.trim()
    mode = parse_mode(Map.get(params, "mode"))

    socket =
      if query == "" do
        socket
        |> assign(:query, "")
        |> assign(:mode, mode)
        |> assign(:form, to_form(%{"query" => ""}, as: :trace))
        |> assign(:searched?, false)
        |> assign(:result, %{lots: [], batches: []})
      else
        result = Traceability.lookup(query, actor: socket.assigns[:current_user], mode: mode)

        socket
        |> assign(:query, query)
        |> assign(:mode, mode)
        |> assign(:form, to_form(%{"query" => query}, as: :trace))
        |> assign(:searched?, true)
        |> assign(:result, result)
      end

    {:noreply,
     Navigation.assign(socket, :production, [
       Navigation.root(:production),
       Navigation.page(:production, :traceability)
     ])}
  end

  @impl true
  def handle_event("search", %{"trace" => %{"query" => query}}, socket) do
    query = String.trim(query)

    params =
      if query == "",
        do: %{mode: socket.assigns.mode},
        else: %{mode: socket.assigns.mode, q: query}

    {:noreply, push_patch(socket, to: ~p"/manage/production/traceability?#{params}")}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/manage/production/traceability?#{%{mode: parse_mode(mode)}}"
     )}
  end

  @impl true
  def handle_event("place_on_hold", %{"lot-id" => lot_id}, socket) do
    update_lot_status(
      socket,
      lot_id,
      :place_on_hold,
      "Lot placed on hold. It is now excluded from production."
    )
  end

  @impl true
  def handle_event("release_hold", %{"lot-id" => lot_id}, socket) do
    update_lot_status(
      socket,
      lot_id,
      :release_hold,
      "Lot released and available for production again."
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Page.page>
      <div class="overflow-hidden rounded-xl border border-stone-200 bg-white shadow-sm print:hidden">
        <div class="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-start sm:justify-between sm:px-5">
          <div class="flex max-w-2xl items-start gap-3">
            <div class="flex h-9 w-9 flex-none items-center justify-center rounded-lg border border-indigo-100 bg-indigo-50 text-indigo-700">
              <.icon name="hero-arrows-right-left" class="h-4 w-4" />
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-indigo-700">
                Traceability
              </p>
              <h1 class="mt-0.5 text-xl font-semibold tracking-tight text-stone-900">Trace Center</h1>
              <p class="mt-1 text-sm leading-5 text-stone-500">
                Follow ingredient lots to customers or finished batches back to their source.
              </p>
            </div>
          </div>
          <div :if={@searched?} class="flex flex-none items-center gap-2 pl-12 print:hidden sm:pl-0">
            <.link href={~p"/manage/production/traceability/export.csv?#{%{mode: @mode, q: @query}}"}>
              <.button id="export-traceability" variant={:outline}>
                <.icon name="hero-arrow-down-tray" class="h-4 w-4" /> Export CSV
              </.button>
            </.link>
            <.button id="print-traceability" variant={:outline} onclick="window.print()">
              <.icon name="hero-printer" class="h-4 w-4" /> Print
            </.button>
          </div>
        </div>

        <div class="grid gap-4 border-t border-stone-200 px-4 py-4 sm:px-5 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.35fr)] xl:items-end">
          <div>
            <p class="mb-2 text-xs font-medium text-stone-500">Trace direction</p>
            <div
              id="trace-direction"
              class="grid grid-cols-3 gap-1 rounded-lg border border-stone-200 bg-stone-50 p-1"
            >
              <.mode_button
                mode={:forward}
                current={@mode}
                icon="hero-arrow-right"
                title="Forward"
                description="Lot → customer"
              />
              <.mode_button
                mode={:backward}
                current={@mode}
                icon="hero-arrow-left"
                title="Backward"
                description="Batch → source"
              />
              <.mode_button
                mode={:recall}
                current={@mode}
                icon="hero-shield-exclamation"
                title="Recall"
                description="Scope & act"
              />
            </div>
          </div>

          <.form for={@form} id="traceability-search-form" phx-submit="search">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
              <div class="flex-1">
                <.input
                  field={@form[:query]}
                  id="traceability-query"
                  type="text"
                  label={search_label(@mode)}
                  placeholder={search_placeholder(@mode)}
                  list="traceability-recent-codes"
                  autocomplete="off"
                  required
                />
                <datalist id="traceability-recent-codes">
                  <option :for={lot <- @recent_lots} value={lot.supplier_lot_code || lot.lot_code} />
                  <option :for={batch <- @recent_batches} value={batch.batch_code} />
                </datalist>
              </div>
              <.button id="traceability-search-button" type="submit" variant={:primary}>
                <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Trace
              </.button>
            </div>
          </.form>
        </div>
      </div>

      <section :if={!@searched?} id="traceability-guide" class="mt-6">
        <div class="mb-3 flex items-center justify-between">
          <div>
            <h2 class="text-base font-semibold text-stone-900">Recent traceable records</h2>
            <p class="mt-1 text-sm text-stone-500">
              Open a recent supplier lot or finished batch in one click.
            </p>
          </div>
        </div>
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <.link
            :for={lot <- @recent_lots}
            navigate={
              ~p"/manage/production/traceability?#{%{mode: :forward, q: lot.supplier_lot_code || lot.lot_code}}"
            }
            class="group transition-[border-color,background-color] rounded-xl border border-stone-200 bg-white p-4 duration-150 hover:bg-indigo-50/30 hover:border-indigo-200"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs font-medium uppercase tracking-wide text-stone-500">Supplier lot</p>
                <p class="font-mono mt-1 text-sm font-semibold text-stone-900">
                  {lot.supplier_lot_code || lot.lot_code}
                </p>
                <p class="mt-1 text-sm text-stone-600">
                  {lot.material.name} · {supplier_name(lot.supplier)}
                </p>
              </div>
              <.status_badge status={lot.status} />
            </div>
          </.link>
          <.link
            :for={batch <- @recent_batches}
            navigate={~p"/manage/production/traceability?#{%{mode: :backward, q: batch.batch_code}}"}
            class="group transition-[border-color,background-color] rounded-xl border border-stone-200 bg-white p-4 duration-150 hover:bg-indigo-50/30 hover:border-indigo-200"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
                  Finished batch
                </p>
                <p class="font-mono mt-1 text-sm font-semibold text-stone-900">{batch.batch_code}</p>
                <p class="mt-1 text-sm text-stone-600">
                  {batch.product.name} · {batch.order_count} orders
                </p>
              </div>
              <.icon
                name="hero-chevron-right"
                class="h-5 w-5 text-stone-300 group-hover:text-indigo-500"
              />
            </div>
          </.link>
        </div>
      </section>

      <div
        :if={@searched? && @result.lots == [] && @result.batches == []}
        id="traceability-empty"
        class="mt-6 rounded-xl border border-dashed border-stone-300 bg-stone-50 px-6 py-12 text-center"
      >
        <.icon name="hero-magnifying-glass" class="mx-auto h-7 w-7 text-stone-400" />
        <p class="mt-3 font-medium text-stone-900">No trace record found for “{@query}”</p>
        <p class="mt-1 text-sm text-stone-500">
          Check the complete lot or batch code, or choose a different trace direction.
        </p>
      </div>

      <section
        :for={report <- @result.lots}
        id={"ingredient-lot-#{report.lot.id}"}
        class="mt-5 space-y-4"
      >
        <div
          :if={@mode == :recall}
          id="recall-command"
          class="rounded-xl border border-l-2 border-stone-200 border-l-rose-300 bg-white px-4 py-3.5"
        >
          <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div class="flex items-start gap-3">
              <div class="flex h-8 w-8 flex-none items-center justify-center rounded-lg bg-rose-50 text-rose-600">
                <.icon name="hero-shield-exclamation" class="h-4 w-4" />
              </div>
              <div>
                <div class="text-sm font-semibold text-stone-900">Recall command</div>
                <p class="mt-0.5 text-sm text-stone-500">
                  Secure the source lot, then contact every verified destination below.
                </p>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-2 print:hidden">
              <.button
                :if={report.lot.status == :available}
                id={"hold-lot-#{report.lot.id}"}
                variant={:danger}
                phx-click="place_on_hold"
                phx-value-lot-id={report.lot.id}
              >
                <.icon name="hero-pause-circle" class="h-4 w-4" /> Place lot on hold
              </.button>
              <.button
                :if={report.lot.status == :on_hold}
                id={"release-lot-#{report.lot.id}"}
                variant={:outline}
                phx-click="release_hold"
                phx-value-lot-id={report.lot.id}
              >
                Release hold
              </.button>
            </div>
          </div>
        </div>

        <div
          id="recall-summary"
          class="grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-stone-200 bg-stone-200 xl:grid-cols-4"
        >
          <.summary_stat
            label="Lot status"
            value={status_label(report.lot.status)}
            tone={status_tone(report.lot.status)}
          />
          <.summary_stat
            label="Stock on hand"
            value={format_amount(report.lot.material.unit, report.lot.current_stock || D.new(0))}
          />
          <.summary_stat label="Affected batches" value={to_string(length(report.batches))} />
          <.summary_stat
            label="Customer destinations"
            value={to_string(affected_customer_count(report))}
            tone={if affected_customer_count(report) > 0, do: :danger, else: :neutral}
          />
        </div>

        <Page.surface>
          <:header>
            <div>
              <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
                Ingredient lot genealogy
              </p>
              <h2 class="font-mono mt-1 break-all text-base font-semibold leading-6 text-stone-900 sm:text-lg">
                {report.lot.supplier_lot_code || report.lot.lot_code}
              </h2>
              <p :if={report.lot.supplier_lot_code} class="text-xs text-stone-500">
                Internal {report.lot.lot_code}
              </p>
            </div>
          </:header>

          <div
            id={"trace-chain-#{report.lot.id}"}
            class="grid items-stretch gap-2 lg:grid-cols-[1fr_auto_1fr_auto_1fr_auto_1fr]"
          >
            <.chain_node
              icon="hero-building-storefront"
              eyebrow="Source"
              title={supplier_name(report.source.supplier)}
              detail={report.source.purchase_order_reference || "No purchase order"}
            />
            <.chain_arrow />
            <.chain_node
              icon="hero-archive-box"
              eyebrow="Ingredient lot"
              title={report.lot.supplier_lot_code || report.lot.lot_code}
              detail={report.lot.material.name}
              mono
            />
            <.chain_arrow />
            <.chain_node
              icon="hero-cog-6-tooth"
              eyebrow="Production"
              title={pluralize(length(report.batches), "finished batch")}
              detail={batch_codes(report)}
            />
            <.chain_arrow />
            <.chain_node
              icon="hero-user-group"
              eyebrow="Destinations"
              title={pluralize(affected_customer_count(report), "customer")}
              detail={pluralize(affected_order_count(report), "order")}
            />
          </div>

          <div class="mt-5 grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-stone-200 bg-stone-200 xl:grid-cols-4">
            <.fact label="Material" value={report.lot.material.name} />
            <.fact
              label="Received quantity"
              value={
                format_amount(report.lot.material.unit, report.lot.received_quantity || D.new(0))
              }
            />
            <.fact label="Received" value={format_trace_time(report.source.received_at, @time_zone)} />
            <.fact label="Expiry" value={format_trace_date(report.lot.expiry_date)} />
          </div>

          <div
            :if={report.source.supplier && report.source.supplier.address}
            class="mt-4 text-sm text-stone-600"
          >
            <span class="font-medium text-stone-700">Supplier address:</span>
            {address_text(report.source.supplier.address)}
          </div>

          <div class="mt-7">
            <div class="flex items-end justify-between gap-3">
              <div>
                <h3 class="text-sm font-semibold text-stone-900">
                  Affected finished batches and customers
                </h3>
                <p class="mt-1 text-xs text-stone-500">
                  Quantities are tied to the frozen batch allocations.
                </p>
              </div>
            </div>
            <div
              :if={report.batches == []}
              class="mt-3 rounded-lg border border-dashed border-stone-300 bg-stone-50 p-5 text-sm text-stone-500"
            >
              This ingredient lot has not been consumed by a production batch.
            </div>
            <div
              :for={usage <- report.batches}
              class="mt-3 overflow-hidden rounded-xl border border-stone-200"
            >
              <div class="flex flex-wrap items-center justify-between gap-2 bg-stone-50 px-4 py-3">
                <div>
                  <.link
                    navigate={~p"/manage/production/batches/#{usage.batch.batch_code}"}
                    class="font-mono text-sm font-semibold text-indigo-700 hover:text-indigo-600"
                  >
                    {usage.batch.batch_code}
                  </.link>
                  <span class="ml-2 text-sm text-stone-700">{usage.batch.product.name}</span>
                </div>
                <div class="text-sm text-stone-600">
                  Used {format_amount(report.lot.material.unit, usage.quantity_used)}
                </div>
              </div>
              <div :if={usage.orders != []} class="hidden sm:block">
                <.table
                  id={"trace-orders-#{usage.batch.id}"}
                  rows={usage.orders}
                  table_class="w-full"
                >
                  <:col :let={row} label="Order">
                    <.link navigate={~p"/manage/orders/#{row.reference}"}><.kbd>
                      {format_reference(row.reference)}
                    </.kbd></.link>
                  </:col>
                  <:col :let={row} label="Customer">{row.customer_name || "—"}</:col>
                  <:col :let={row} label="Quantity">{D.to_string(row.quantity)}</:col>
                  <:col :let={row} label="Contact" class="hidden md:table-cell">
                    <div>{row.customer_email || "—"}</div>
                    <div class="text-xs text-stone-500">{row.customer_phone}</div>
                  </:col>
                  <:col :let={row} label="Ship to" class="hidden lg:table-cell">
                    {address_text(row.shipping_address)}
                  </:col>
                </.table>
              </div>
              <div
                :if={usage.orders != []}
                id={"trace-orders-mobile-#{usage.batch.id}"}
                class="divide-y divide-stone-100 sm:hidden"
              >
                <div :for={row <- usage.orders} class="p-4">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <p class="font-medium text-stone-900">{row.customer_name || "—"}</p>
                      <.link
                        navigate={~p"/manage/orders/#{row.reference}"}
                        class="font-mono mt-1 block text-xs text-indigo-700"
                      >
                        {format_reference(row.reference)}
                      </.link>
                    </div>
                    <div class="flex-none text-right">
                      <p class="text-[10px] font-semibold uppercase tracking-wide text-stone-400">
                        Quantity
                      </p>
                      <p class="mt-1 text-sm font-semibold text-stone-900">
                        {D.to_string(row.quantity)}
                      </p>
                    </div>
                  </div>
                  <div class="mt-3 border-t border-stone-100 pt-3 text-xs leading-5 text-stone-500">
                    <p class="break-all">{row.customer_email || "—"}</p>
                    <p :if={row.customer_phone}>{row.customer_phone}</p>
                    <p class="mt-1">{address_text(row.shipping_address)}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div
            :if={@mode == :recall}
            id="recall-checklist"
            class="mt-7 rounded-xl border border-stone-200 bg-stone-50 p-5"
          >
            <h3 class="text-sm font-semibold text-stone-900">Recall response checklist</h3>
            <div class="mt-4 grid gap-3 md:grid-cols-2">
              <.check_step
                done={report.lot.status == :on_hold}
                number="1"
                title="Stop further use"
                detail="Place the source lot on hold so FIFO/FEFO cannot select it."
              />
              <.check_step
                done={false}
                number="2"
                title="Isolate remaining stock"
                detail={"Locate and isolate #{format_amount(report.lot.material.unit, report.lot.current_stock || D.new(0))} still on hand."}
              />
              <.check_step
                done={affected_customer_count(report) == 0}
                number="3"
                title="Contact destinations"
                detail={"Notify #{pluralize(affected_customer_count(report), "affected customer")} across #{pluralize(affected_order_count(report), "order")}."}
              />
              <.check_step
                done={false}
                number="4"
                title="Preserve the record"
                detail="Export CSV or print this frozen trace report for the recall file."
              />
            </div>
          </div>
        </Page.surface>
      </section>

      <section :for={report <- @result.batches} id={"finished-batch-#{report.batch.id}"} class="mt-6">
        <Page.surface>
          <:header>
            <div>
              <p class="text-xs font-medium uppercase tracking-wide text-stone-500">
                Finished batch genealogy
              </p>
              <h2 class="font-mono mt-1 break-all text-base font-semibold leading-6 text-stone-900 sm:text-lg">
                {report.batch.batch_code}
              </h2>
              <p class="text-sm text-stone-500">{report.product.name}</p>
            </div>
          </:header>

          <div
            id={"batch-trace-chain-#{report.batch.id}"}
            class="grid items-stretch gap-2 lg:grid-cols-[1fr_auto_1fr_auto_1fr]"
          >
            <.chain_node
              icon="hero-building-storefront"
              eyebrow="Ingredient sources"
              title={pluralize(unique_supplier_count(report), "supplier")}
              detail={pluralize(length(report.lots), "source lot")}
            />
            <.chain_arrow />
            <.chain_node
              icon="hero-cube"
              eyebrow="Finished batch"
              title={report.batch.batch_code}
              detail={report.product.name}
              mono
            />
            <.chain_arrow />
            <.chain_node
              icon="hero-user-group"
              eyebrow="Destinations"
              title={pluralize(batch_customer_count(report), "customer")}
              detail={pluralize(length(report.orders), "order")}
            />
          </div>

          <div class="mt-5 grid grid-cols-3 gap-px overflow-hidden rounded-lg border border-stone-200 bg-stone-200">
            <.fact label="Status" value={to_string(report.batch.status)} />
            <.fact label="Produced quantity" value={D.to_string(report.batch.produced_qty)} />
            <.fact label="Completed" value={format_trace_time(report.produced_at, @time_zone)} />
          </div>

          <div class="mt-7">
            <h3 class="text-sm font-semibold text-stone-900">Ingredient sources</h3>
            <div class="hidden sm:block">
              <.table
                id={"trace-lots-#{report.batch.id}"}
                rows={report.lots}
                no_margin
                variant={:compact}
                wrapper_class="mt-4 !px-0"
                table_class="w-full"
              >
                <:col :let={usage} label="Material">{usage.lot.material.name}</:col>
                <:col :let={usage} label="Supplier lot">
                  <.link
                    navigate={
                      ~p"/manage/production/traceability?#{%{mode: :forward, q: usage.lot.supplier_lot_code || usage.lot.lot_code}}"
                    }
                    class="font-mono text-xs text-indigo-700 hover:text-indigo-600"
                  >
                    {usage.lot.supplier_lot_code || usage.lot.lot_code}
                  </.link>
                </:col>
                <:col :let={usage} label="Supplier">
                  {supplier_name(usage.source.supplier)}
                </:col>
                <:col :let={usage} label="Purchase order" class="hidden lg:table-cell">
                  {usage.source.purchase_order_reference || "—"}
                </:col>
                <:col :let={usage} label="Used">
                  {format_amount(usage.lot.material.unit, usage.quantity_used)}
                </:col>
              </.table>
            </div>
            <div
              id={"trace-lots-mobile-#{report.batch.id}"}
              class="mt-3 space-y-2 sm:hidden"
            >
              <div
                :for={usage <- report.lots}
                class="rounded-lg border border-stone-200 bg-white p-3.5"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <p class="font-medium text-stone-900">{usage.lot.material.name}</p>
                    <.link
                      navigate={
                        ~p"/manage/production/traceability?#{%{mode: :forward, q: usage.lot.supplier_lot_code || usage.lot.lot_code}}"
                      }
                      class="font-mono mt-1 block break-all text-xs text-indigo-700"
                    >
                      {usage.lot.supplier_lot_code || usage.lot.lot_code}
                    </.link>
                  </div>
                  <div class="flex-none text-right">
                    <p class="text-[10px] font-semibold uppercase tracking-wide text-stone-400">
                      Used
                    </p>
                    <p class="mt-1 text-sm font-semibold text-stone-900">
                      {format_amount(usage.lot.material.unit, usage.quantity_used)}
                    </p>
                  </div>
                </div>
                <dl class="mt-3 grid gap-3 border-t border-stone-100 pt-3 text-xs sm:grid-cols-2">
                  <div>
                    <dt class="font-medium text-stone-400">Supplier</dt>
                    <dd class="mt-0.5 text-stone-600">{supplier_name(usage.source.supplier)}</dd>
                  </div>
                  <div>
                    <dt class="font-medium text-stone-400">Purchase order</dt>
                    <dd class="font-mono mt-0.5 break-all text-stone-600">
                      {usage.source.purchase_order_reference || "—"}
                    </dd>
                  </div>
                </dl>
              </div>
            </div>
          </div>

          <div class="mt-7">
            <h3 class="text-sm font-semibold text-stone-900">Customer destinations</h3>
            <div class="hidden sm:block">
              <.table
                id={"trace-destinations-#{report.batch.id}"}
                rows={report.orders}
                no_margin
                variant={:compact}
                wrapper_class="mt-4 !px-0"
                table_class="w-full"
              >
                <:col :let={row} label="Order">
                  <.link navigate={~p"/manage/orders/#{row.order.reference}"}><.kbd>
                    {format_reference(row.order.reference)}
                  </.kbd></.link>
                </:col>
                <:col :let={row} label="Customer">{row.customer_name || "—"}</:col>
                <:col :let={row} label="Quantity">{D.to_string(row.quantity)}</:col>
              </.table>
            </div>
            <div
              id={"trace-destinations-mobile-#{report.batch.id}"}
              class="mt-3 space-y-2 sm:hidden"
            >
              <div
                :for={row <- report.orders}
                class="flex items-center justify-between gap-3 rounded-lg border border-stone-200 bg-white p-3.5"
              >
                <div>
                  <p class="font-medium text-stone-900">{row.customer_name || "—"}</p>
                  <.link
                    navigate={~p"/manage/orders/#{row.order.reference}"}
                    class="font-mono mt-1 block text-xs text-indigo-700"
                  >
                    {format_reference(row.order.reference)}
                  </.link>
                </div>
                <div class="flex-none text-right">
                  <p class="text-[10px] font-semibold uppercase tracking-wide text-stone-400">
                    Quantity
                  </p>
                  <p class="mt-1 text-sm font-semibold text-stone-900">{D.to_string(row.quantity)}</p>
                </div>
              </div>
            </div>
          </div>
        </Page.surface>
      </section>
    </Page.page>
    """
  end

  attr :mode, :atom, required: true
  attr :current, :atom, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp mode_button(assigns) do
    ~H"""
    <button
      id={"trace-mode-#{@mode}"}
      type="button"
      phx-click="set_mode"
      phx-value-mode={@mode}
      title={"#{@title}: #{@description}"}
      class={[
        "transition-[background-color,color,box-shadow,transform] flex min-w-0 items-center justify-center gap-1.5 rounded-md px-1.5 py-2 text-left duration-150 active:scale-[0.98] sm:gap-2 sm:px-3",
        if(@current == @mode,
          do: "bg-white text-indigo-800 shadow-sm ring-1 ring-stone-200",
          else: "text-stone-600 hover:bg-white hover:text-stone-900"
        )
      ]}
    >
      <span class={[
        "flex h-6 w-6 flex-none items-center justify-center rounded-md sm:h-7 sm:w-7",
        if(@current == @mode, do: "bg-indigo-50 text-indigo-700", else: "text-stone-400")
      ]}>
        <.icon name={@icon} class="h-4 w-4" />
      </span>
      <span class="min-w-0">
        <span class="block truncate text-xs font-medium sm:text-sm">{@title}</span>
        <span class="sr-only">{@description}</span>
      </span>
    </button>
    """
  end

  attr :icon, :string, required: true
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true
  attr :mono, :boolean, default: false

  defp chain_node(assigns) do
    ~H"""
    <div class="flex items-start gap-3 rounded-xl border border-stone-200 bg-white p-3.5 lg:block lg:p-4">
      <div class="flex h-8 w-8 flex-none items-center justify-center rounded-lg bg-indigo-50 text-indigo-700">
        <.icon name={@icon} class="h-4 w-4" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-stone-500 lg:mt-3">
          {@eyebrow}
        </p>
        <p class={[
          "mt-1 break-words text-sm font-semibold leading-5 text-stone-900 lg:truncate",
          @mono && "font-mono text-xs"
        ]}>
          {@title}
        </p>
        <p class="mt-1 truncate text-xs text-stone-500">{@detail}</p>
      </div>
    </div>
    """
  end

  defp chain_arrow(assigns) do
    ~H"""
    <div class="flex items-center justify-center py-0.5 text-stone-300 lg:py-0">
      <.icon name="hero-arrow-right" class="h-5 w-5 rotate-90 lg:rotate-0" />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :atom, default: :neutral

  defp summary_stat(assigns) do
    ~H"""
    <div class="bg-white px-3 py-3 sm:px-4 sm:py-3.5">
      <p class="text-[10px] font-medium uppercase tracking-wide text-stone-500 sm:text-xs">
        {@label}
      </p>
      <p class={[
        "mt-1 text-base font-semibold sm:text-lg",
        @tone == :danger && "text-rose-700",
        @tone == :warning && "text-amber-700",
        @tone == :success && "text-emerald-700",
        @tone == :neutral && "text-stone-900"
      ]}>
        {@value}
      </p>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex rounded-full border px-2.5 py-1 text-xs font-medium capitalize",
      @status == :available && "border-emerald-200 bg-emerald-50 text-emerald-700",
      @status == :on_hold && "border-amber-200 bg-amber-50 text-amber-700",
      @status == :rejected && "border-rose-200 bg-rose-50 text-rose-700"
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  attr :done, :boolean, required: true
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true

  defp check_step(assigns) do
    ~H"""
    <div class="flex gap-3 rounded-lg border border-stone-200 bg-white p-3">
      <div class={[
        "flex h-7 w-7 flex-none items-center justify-center rounded-full text-xs font-semibold",
        if(@done, do: "bg-emerald-100 text-emerald-700", else: "bg-stone-100 text-stone-600")
      ]}>
        <.icon :if={@done} name="hero-check" class="h-4 w-4" />
        <span :if={!@done}>{@number}</span>
      </div>
      <div>
        <p class="text-sm font-medium text-stone-900">{@title}</p>
        <p class="mt-0.5 text-xs leading-5 text-stone-500">{@detail}</p>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp fact(assigns) do
    ~H"""
    <div class="bg-white px-3 py-3 sm:px-4">
      <p class="text-[10px] uppercase tracking-wide text-stone-500 sm:text-xs">{@label}</p>
      <p class="mt-1 text-sm font-medium text-stone-900">{@value}</p>
    </div>
    """
  end

  defp update_lot_status(socket, lot_id, action, message) do
    report = Enum.find(socket.assigns.result.lots, &(&1.lot.id == lot_id))

    result =
      case report do
        nil ->
          nil

        report ->
          report.lot
          |> Changeset.for_update(action, %{})
          |> Ash.update(actor: socket.assigns.current_user)
      end

    case result do
      {:ok, _lot} ->
        result =
          Traceability.lookup(socket.assigns.query,
            actor: socket.assigns.current_user,
            mode: socket.assigns.mode
          )

        {:noreply, socket |> assign(:result, result) |> put_flash(:info, message)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not update lot status: #{inspect(error)}")}

      nil ->
        {:noreply, put_flash(socket, :error, "Lot not found")}
    end
  end

  defp parse_mode("forward"), do: :forward
  defp parse_mode(:forward), do: :forward
  defp parse_mode("backward"), do: :backward
  defp parse_mode(:backward), do: :backward
  defp parse_mode(_mode), do: :recall

  defp search_label(:forward), do: "Supplier or internal ingredient lot"
  defp search_label(:backward), do: "Finished product batch"
  defp search_label(:recall), do: "Lot or finished batch to investigate"

  defp search_placeholder(:forward), do: "e.g. SUP-LOT-1042"
  defp search_placeholder(:backward), do: "e.g. B-20260904-BREAD-001"
  defp search_placeholder(:recall), do: "Scan or enter any lot or batch code"

  defp status_label(:on_hold), do: "On hold"
  defp status_label(:rejected), do: "Rejected"
  defp status_label(_status), do: "Available"

  defp status_tone(:on_hold), do: :warning
  defp status_tone(:rejected), do: :danger
  defp status_tone(_status), do: :success

  defp affected_orders(report), do: Enum.flat_map(report.batches, & &1.orders)

  defp affected_order_count(report) do
    report |> affected_orders() |> Enum.uniq_by(& &1.reference) |> length()
  end

  defp affected_customer_count(report) do
    report
    |> affected_orders()
    |> Enum.reject(&is_nil(&1.customer_name))
    |> Enum.uniq_by(&{&1.customer_name, &1.customer_email})
    |> length()
  end

  defp batch_customer_count(report) do
    report.orders
    |> Enum.reject(&is_nil(&1.customer_name))
    |> Enum.uniq_by(& &1.customer_name)
    |> length()
  end

  defp unique_supplier_count(report) do
    report.lots
    |> Enum.map(&supplier_name(&1.source.supplier))
    |> Enum.reject(&(&1 == "—"))
    |> Enum.uniq()
    |> length()
  end

  defp batch_codes(report) do
    case Enum.map_join(report.batches, ", ", & &1.batch.batch_code) do
      "" -> "Not used in production"
      value -> value
    end
  end

  defp pluralize(count, word), do: "#{count} #{word}#{if count == 1, do: "", else: "s"}"

  defp supplier_name(nil), do: "—"
  defp supplier_name(supplier), do: supplier.name

  defp address_text(nil), do: "—"

  defp address_text(address) do
    [
      Map.get(address, :street),
      [Map.get(address, :zip), Map.get(address, :city)]
      |> Enum.reject(&blank?/1)
      |> Enum.join(" "),
      Map.get(address, :state),
      Map.get(address, :country)
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(", ")
    |> case do
      "" -> "—"
      text -> text
    end
  end

  defp blank?(value), do: value in [nil, ""]

  defp format_trace_time(nil, _time_zone), do: "—"
  defp format_trace_time(value, time_zone), do: format_time(value, time_zone)
  defp format_trace_date(nil), do: "—"
  defp format_trace_date(value), do: Calendar.strftime(value, "%Y-%m-%d")
end
