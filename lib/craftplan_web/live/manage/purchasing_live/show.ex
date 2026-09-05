defmodule CraftplanWeb.PurchasingLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving
  alias CraftplanWeb.Navigation

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      <div class="flex flex-wrap items-center gap-2.5">
        <span>{@po.reference}</span>
        <.badge text={po_status_label(@po.status)} />
      </div>
      <:actions>
        <.link patch={~p"/manage/purchasing/#{@po.reference}/add_item"}>
          <.button variant={:outline}>Add Item</.button>
        </.link>
        <.button
          :if={@po.status != :received}
          id="open-receive-po"
          variant={:primary}
          phx-click="open_receive"
        >
          Receive Stock
        </.button>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-4">
      <.tabs_content :if={@live_action in [:show]}>
        <.list>
          <:item title="Reference">
            <.kbd>{@po.reference}</.kbd>
          </:item>
          <:item title="Supplier">{@po.supplier.name}</:item>
          <:item title="Status"><.badge text={to_string(@po.status)} /></:item>
          <:item title="Ordered At">{format_time(@po.ordered_at, @time_zone)}</:item>
          <:item title="Received At">{format_time(@po.received_at, @time_zone)}</:item>
        </.list>
      </.tabs_content>
      <.tabs_content :if={@live_action not in [:show]}>
        <div class="hidden sm:block">
          <.table id="po-items" rows={@po.items}>
            <:col :let={i} label="Material">{i.material.name}</:col>
            <:col :let={i} label="Quantity">{format_amount(i.material.unit, i.quantity)}</:col>
            <:col :let={i} label="Received">
              <div class="min-w-28">
                <div>
                  <span class="font-medium text-stone-900">
                    {format_amount(i.material.unit, received_quantity(i))}
                  </span>
                  <span class="text-stone-400">
                    / {format_amount(i.material.unit, i.quantity)}
                  </span>
                </div>
                <div class="mt-2 h-1 overflow-hidden rounded-full bg-stone-100">
                  <div
                    class="h-full rounded-full bg-indigo-500"
                    style={"width: #{progress_percent(received_quantity(i), i.quantity)}%"}
                  >
                  </div>
                </div>
              </div>
            </:col>
            <:col :let={i} label="Unit Price">
              {format_money(@settings.currency, i.unit_price || Decimal.new(0))}
            </:col>
            <:col :let={i} label="Supplier Lot">
              <div :if={i.lots != []} class="flex flex-wrap gap-1.5">
                <.link
                  :for={lot <- i.lots}
                  navigate={
                    ~p"/manage/production/traceability?mode=forward&q=#{lot.supplier_lot_code || lot.lot_code}"
                  }
                  class="font-mono rounded border border-stone-300 bg-stone-50 px-1.5 py-1 text-xs text-stone-700 hover:border-indigo-300 hover:text-indigo-700"
                >
                  {lot.supplier_lot_code || lot.lot_code}
                </.link>
              </div>
              <span :if={i.lots == []} class="text-stone-400">—</span>
            </:col>
          </.table>
        </div>
        <div id="po-items-mobile" class="space-y-3 sm:hidden">
          <div
            :for={item <- @po.items}
            id={"po-item-mobile-#{item.id}"}
            class="rounded-xl border border-stone-200 bg-white p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-medium text-stone-900">{item.material.name}</p>
                <p class="mt-1 text-xs text-stone-500">
                  Ordered {format_amount(item.material.unit, item.quantity)}
                </p>
              </div>
              <p class="flex-none text-sm font-medium text-stone-700">
                {format_money(@settings.currency, item.unit_price || Decimal.new(0))}
              </p>
            </div>

            <div class="mt-4">
              <div class="flex items-center justify-between gap-3 text-xs">
                <span class="font-medium text-stone-500">Received</span>
                <span class="text-stone-700">
                  {format_amount(item.material.unit, received_quantity(item))} / {format_amount(
                    item.material.unit,
                    item.quantity
                  )}
                </span>
              </div>
              <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-stone-100">
                <div
                  class="h-full rounded-full bg-indigo-500"
                  style={"width: #{progress_percent(received_quantity(item), item.quantity)}%"}
                >
                </div>
              </div>
            </div>

            <div :if={item.lots != []} class="mt-4 border-t border-stone-100 pt-3">
              <p class="text-[10px] font-semibold uppercase tracking-wide text-stone-400">
                Supplier lots
              </p>
              <div class="mt-2 flex flex-wrap gap-1.5">
                <.link
                  :for={lot <- item.lots}
                  navigate={
                    ~p"/manage/production/traceability?mode=forward&q=#{lot.supplier_lot_code || lot.lot_code}"
                  }
                  class="font-mono rounded border border-stone-200 bg-stone-50 px-2 py-1 text-xs text-indigo-700"
                >
                  {lot.supplier_lot_code || lot.lot_code}
                </.link>
              </div>
            </div>
          </div>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Add Item to #{@po.reference}"}
      on_cancel={
        JS.patch(
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        )
      }
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_user={@current_user}
        materials={@materials}
        po_id={@po.id}
        purchase_order_item={nil}
        patch={
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        }
      />
    </.modal>

    <.modal
      :if={@receiving?}
      id="receive-po-modal"
      show
      title={"Receive #{@po.reference}"}
      description="Match the delivery to supplier lots. Split a line when one material arrives under more than one lot code."
      max_width="max-w-5xl"
      on_cancel={JS.push("close_receive")}
    >
      <.form
        for={@receive_form}
        id="receive-po-form"
        phx-change="validate_receive"
        phx-submit="receive"
      >
        <div class="mb-5 flex flex-col gap-3 border-b border-stone-200 pb-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-semibold text-stone-900">What arrived today?</p>
            <p class="mt-1 text-xs text-stone-600">
              Receive everything outstanding, or record a partial delivery and finish the PO later.
            </p>
          </div>
          <div
            id="receipt-mode"
            class="flex w-full rounded-lg border border-stone-300 bg-stone-50 p-1 sm:w-auto"
          >
            <button
              id="receive-mode-all"
              type="button"
              phx-click="set_receive_mode"
              phx-value-mode="all"
              class={[
                "transition-[background-color,color,box-shadow,transform] flex-1 whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium duration-150 active:scale-[0.98]",
                if(@receipt_mode == :all,
                  do: "bg-indigo-50 text-indigo-700 shadow-sm ring-1 ring-indigo-100",
                  else: "text-stone-600 hover:bg-stone-100"
                )
              ]}
            >
              Receive all
            </button>
            <button
              id="receive-mode-partial"
              type="button"
              phx-click="set_receive_mode"
              phx-value-mode="partial"
              class={[
                "transition-[background-color,color,box-shadow,transform] flex-1 whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium duration-150 active:scale-[0.98]",
                if(@receipt_mode == :partial,
                  do: "bg-indigo-50 text-indigo-700 shadow-sm ring-1 ring-indigo-100",
                  else: "text-stone-600 hover:bg-stone-100"
                )
              ]}
            >
              Partial delivery
            </button>
          </div>
        </div>

        <div id="receipt-items" class="space-y-4">
          <div
            :for={row <- @receipt_rows}
            id={"receipt-item-#{row.item_id}"}
            class={[
              "transition-[border-color,background-color,opacity] rounded-xl border p-4 duration-150",
              row.included && "border-stone-200 bg-white",
              !row.included && "opacity-65 border-stone-200 bg-stone-50"
            ]}
          >
            <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
              <div class="flex items-start gap-3">
                <label :if={@receipt_mode == :partial} class="mt-0.5 flex items-center">
                  <input
                    type="checkbox"
                    name={"receipt[items][#{row.item_id}][included]"}
                    value="true"
                    checked={row.included}
                    class="rounded border-stone-300 text-indigo-600 focus:ring-indigo-500"
                    aria-label={"Include #{row.material.name} in this delivery"}
                  />
                </label>
                <div>
                  <div class="font-semibold text-stone-900">{row.material.name}</div>
                  <div class="mt-1 text-xs text-stone-500">
                    Ordered {format_amount(row.material.unit, row.ordered)} · Already received {format_amount(
                      row.material.unit,
                      row.received
                    )}
                  </div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-xs font-medium uppercase tracking-wide text-stone-500">
                  Outstanding
                </div>
                <div class="mt-1 text-sm font-semibold text-stone-900">
                  {format_amount(row.material.unit, row.remaining)}
                </div>
              </div>
            </div>

            <div :if={row.included} id={"receipt-lots-#{row.item_id}"} class="space-y-3">
              <div
                :for={{line, line_number} <- Enum.with_index(row.lines, 1)}
                id={"receipt-lot-#{row.item_id}-#{line.key}"}
                class="bg-stone-50/70 rounded-lg border border-stone-200 p-3"
              >
                <div class="grid gap-3 lg:grid-cols-[1.3fr_0.8fr_0.8fr_auto] lg:items-end">
                  <.input
                    type="text"
                    name={"receipt[items][#{row.item_id}][lines][#{line.key}][supplier_lot_code]"}
                    id={"supplier-lot-#{row.item_id}-#{line.key}"}
                    label={"Supplier lot #{line_number} code"}
                    value={line.supplier_lot_code}
                    placeholder="Scan or type the code"
                    required
                  />
                  <.input
                    type="number"
                    name={"receipt[items][#{row.item_id}][lines][#{line.key}][quantity]"}
                    id={"receipt-quantity-#{row.item_id}-#{line.key}"}
                    label={"Quantity (#{unit_abbreviation(row.material.unit)})"}
                    value={line.quantity}
                    min="0"
                    max={Decimal.to_string(row.remaining)}
                    step="any"
                    required
                  />
                  <.input
                    type="date"
                    name={"receipt[items][#{row.item_id}][lines][#{line.key}][expiry_date]"}
                    id={"receipt-expiry-#{row.item_id}-#{line.key}"}
                    label="Expiry date"
                    value={line.expiry_date}
                  />
                  <button
                    :if={length(row.lines) > 1}
                    type="button"
                    phx-click="remove_receipt_lot"
                    phx-value-item-id={row.item_id}
                    phx-value-key={line.key}
                    class="mb-0.5 inline-flex h-9 items-center justify-center rounded-md border border-stone-300 bg-white px-3 text-sm text-stone-600 hover:border-rose-300 hover:text-rose-600"
                    aria-label="Remove lot allocation"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
                <div class="mt-2 flex items-center gap-2 text-xs text-stone-500">
                  <span>Craftplan lot</span>
                  <code class="font-mono rounded bg-white px-1.5 py-0.5 text-stone-700">
                    {internal_lot_code(@po.reference, row, line)}
                  </code>
                </div>
              </div>

              <div class="flex flex-col gap-3 border-t border-stone-200 pt-3 sm:flex-row sm:items-center sm:justify-between">
                <button
                  type="button"
                  phx-click="add_receipt_lot"
                  phx-value-item-id={row.item_id}
                  class="inline-flex items-center gap-1.5 text-sm font-medium text-indigo-700 hover:text-indigo-600"
                >
                  <.icon name="hero-plus-circle" class="h-4 w-4" /> Add another supplier lot
                </button>
                <div class="flex items-center gap-3">
                  <div class="h-1.5 w-24 overflow-hidden rounded-full bg-stone-200">
                    <div
                      class={[
                        "h-full rounded-full",
                        Decimal.lt?(unassigned_quantity(row), Decimal.new(0)) && "bg-rose-500",
                        !Decimal.lt?(unassigned_quantity(row), Decimal.new(0)) && "bg-indigo-500"
                      ]}
                      style={"width: #{progress_percent(assigned_quantity(row), row.remaining)}%"}
                    >
                    </div>
                  </div>
                  <div class={[
                    "text-sm",
                    allocation_valid?(row, @receipt_mode) && "text-emerald-700",
                    !allocation_valid?(row, @receipt_mode) && "text-amber-700"
                  ]}>
                    <%= if Decimal.lt?(unassigned_quantity(row), Decimal.new(0)) do %>
                      Exceeds outstanding by {format_amount(
                        row.material.unit,
                        Decimal.abs(unassigned_quantity(row))
                      )}
                    <% else %>
                      <span class="font-medium">{format_amount(
                        row.material.unit,
                        assigned_quantity(row)
                      )}</span>
                      receiving now
                      <span :if={Decimal.gt?(unassigned_quantity(row), Decimal.new(0))}>
                        · {format_amount(row.material.unit, unassigned_quantity(row))} {if @receipt_mode ==
                                                                                             :partial,
                                                                                           do:
                                                                                             "stays open",
                                                                                           else:
                                                                                             "still required"}
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div
          :if={!@receipt_valid? && @receipt_error}
          id="receipt-validation-error"
          class="mt-4 flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
        >
          <.icon name="hero-exclamation-triangle" class="mt-0.5 h-4 w-4 flex-none" />
          <span>{@receipt_error}</span>
        </div>

        <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between">
          <p class="flex items-center gap-1.5 text-xs text-stone-500">
            <.icon name="hero-lock-closed" class="h-3.5 w-3.5" />
            Every receipt is frozen with its supplier, PO, quantity, and expiry date.
          </p>
          <div class="flex justify-end gap-2">
            <.button type="button" variant={:outline} phx-click="close_receive">Cancel</.button>
            <.button
              id="confirm-receive-po"
              type="submit"
              variant={:primary}
              disabled={!@receipt_valid?}
              phx-disable-with="Receiving..."
            >
              Receive {receipt_lot_count(@receipt_rows)} lot{if receipt_lot_count(@receipt_rows) == 1,
                do: "",
                else: "s"}
            </.button>
          </div>
        </div>
      </.form>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    materials = Inventory.list_materials!(actor: socket.assigns[:current_user])

    {:ok,
     socket
     |> assign(:materials, materials)
     |> assign(:purchasing_tab, :purchase_orders)
     |> assign(:receiving?, false)
     |> assign(:receipt_mode, :all)
     |> assign(:receipt_rows, [])
     |> assign(:receipt_valid?, false)
     |> assign(:receipt_error, nil)
     |> assign(:receive_form, to_form(%{}, as: :receipt))}
  end

  @impl true
  def handle_params(%{"po_ref" => ref}, _uri, socket) do
    opts = [
      actor: socket.assigns[:current_user],
      load: [:supplier, items: [lots: [:received_quantity], material: [:unit]]]
    ]

    case Inventory.get_purchase_order_by_reference(ref, opts) do
      {:ok, nil} ->
        {:noreply,
         socket
         |> put_flash(:error, "Purchase order not found")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:ok, po} ->
        live_action = socket.assigns.live_action

        tabs_links = [
          %{
            label: "Overview",
            navigate: ~p"/manage/purchasing/#{po.reference}",
            active: live_action == :show
          },
          %{
            label: "Items",
            navigate: ~p"/manage/purchasing/#{po.reference}/items",
            active: live_action in [:items, :add_item]
          }
        ]

        socket =
          socket
          |> assign(:po, po)
          |> assign(:tabs_links, tabs_links)

        {:noreply, Navigation.assign(socket, :purchasing, po_trail(po, live_action))}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to load purchase order")
         |> push_navigate(to: ~p"/manage/purchasing")}
    end
  end

  @impl true
  def handle_event("open_receive", _params, socket) do
    rows = build_receipt_rows(socket.assigns.po)

    {:noreply,
     socket
     |> assign(:receiving?, true)
     |> assign(:receipt_mode, :all)
     |> assign_receipt_rows(rows)}
  end

  @impl true
  def handle_event("close_receive", _params, socket) do
    {:noreply, assign(socket, :receiving?, false)}
  end

  @impl true
  def handle_event("set_receive_mode", %{"mode" => mode}, socket) do
    mode = if mode == "partial", do: :partial, else: :all
    rows = Enum.map(socket.assigns.receipt_rows, &Map.put(&1, :included, true))

    {:noreply, socket |> assign(:receipt_mode, mode) |> assign_receipt_rows(rows)}
  end

  @impl true
  def handle_event("validate_receive", %{"receipt" => params}, socket) do
    rows = update_receipt_rows(socket.assigns.receipt_rows, params, socket.assigns.receipt_mode)
    {:noreply, assign_receipt_rows(socket, rows)}
  end

  @impl true
  def handle_event("add_receipt_lot", %{"item-id" => item_id}, socket) do
    rows =
      Enum.map(socket.assigns.receipt_rows, fn
        %{item_id: ^item_id} = row ->
          next_key =
            row.lines
            |> Enum.map(&String.to_integer(&1.key))
            |> Enum.max(fn -> 0 end)
            |> Kernel.+(1)

          Map.update!(row, :lines, &(&1 ++ [blank_receipt_line(Integer.to_string(next_key))]))

        row ->
          row
      end)

    {:noreply, assign_receipt_rows(socket, rows)}
  end

  @impl true
  def handle_event("remove_receipt_lot", %{"item-id" => item_id, "key" => key}, socket) do
    rows =
      Enum.map(socket.assigns.receipt_rows, fn
        %{item_id: ^item_id} = row when length(row.lines) > 1 ->
          Map.update!(row, :lines, &Enum.reject(&1, fn line -> line.key == key end))

        row ->
          row
      end)

    {:noreply, assign_receipt_rows(socket, rows)}
  end

  @impl true
  def handle_event("receive", %{"receipt" => params}, socket) do
    rows = update_receipt_rows(socket.assigns.receipt_rows, params, socket.assigns.receipt_mode)
    {valid?, error} = receipt_validation(rows, socket.assigns.receipt_mode)
    receipts = build_receipts(socket.assigns.po, rows)

    if valid? do
      case Receiving.receive_po(socket.assigns.po.id,
             actor: socket.assigns.current_user,
             lot_receipts: receipts
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:receiving?, false)
           |> put_flash(:info, receipt_success_message(socket.assigns.receipt_mode))
           |> push_navigate(to: ~p"/manage/purchasing/#{socket.assigns.po.reference}/items")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Receive failed: #{inspect(error)}")}
      end
    else
      {:noreply,
       socket
       |> assign_receipt_rows(rows)
       |> assign(:receipt_error, error)}
    end
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    po =
      Inventory.get_purchase_order_by_reference!(socket.assigns.po.reference,
        actor: socket.assigns[:current_user],
        load: [:supplier, items: [lots: [:received_quantity], material: [:unit]]]
      )

    {:noreply,
     socket
     |> assign(:po, po)
     |> put_flash(:info, "Item added to PO")
     |> push_event("close-modal", %{id: "po-item-modal"})}
  end

  defp po_trail(po, :items) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_items, po)
    ]
  end

  defp po_trail(po, :add_item) do
    [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po),
      Navigation.page(:purchasing, :po_add_item, po)
    ]
  end

  defp po_trail(po, _),
    do: [
      Navigation.root(:purchasing),
      Navigation.page(:purchasing, :purchase_orders),
      Navigation.resource(:purchase_order, po)
    ]

  defp build_receipts(po, rows) do
    Enum.flat_map(rows, fn row ->
      if row.included do
        Enum.map(row.lines, fn line ->
          %{
            purchase_order_item_id: row.item_id,
            material_id: row.material_id,
            lot_code: internal_lot_code(po.reference, row, line),
            supplier_lot_code: String.trim(line.supplier_lot_code),
            quantity: line.quantity,
            expiry_date: line.expiry_date
          }
        end)
      else
        []
      end
    end)
  end

  defp build_receipt_rows(po) do
    po.items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, line_number} ->
      received = received_quantity(item)
      remaining = Decimal.sub(item.quantity, received)

      if Decimal.gt?(remaining, Decimal.new(0)) do
        [
          %{
            item_id: item.id,
            material_id: item.material_id,
            material: item.material,
            po_line: line_number,
            existing_lot_count: length(item.lots),
            ordered: item.quantity,
            received: received,
            remaining: remaining,
            included: true,
            lines: [
              %{
                blank_receipt_line("1")
                | quantity: Decimal.to_string(remaining, :normal)
              }
            ]
          }
        ]
      else
        []
      end
    end)
  end

  defp blank_receipt_line(key) do
    %{key: key, supplier_lot_code: "", quantity: "", expiry_date: ""}
  end

  defp update_receipt_rows(rows, params, mode) do
    item_params = Map.get(params, "items", %{})

    Enum.map(rows, fn row ->
      values = Map.get(item_params, row.item_id, %{})
      line_values = Map.get(values, "lines", %{})

      lines =
        Enum.map(row.lines, fn line ->
          submitted = Map.get(line_values, line.key, %{})

          %{
            line
            | supplier_lot_code: Map.get(submitted, "supplier_lot_code", line.supplier_lot_code),
              quantity: Map.get(submitted, "quantity", line.quantity),
              expiry_date: Map.get(submitted, "expiry_date", line.expiry_date)
          }
        end)

      included = mode == :all or Map.get(values, "included") == "true"
      %{row | included: included, lines: lines}
    end)
  end

  defp assign_receipt_rows(socket, rows) do
    {valid?, error} = receipt_validation(rows, socket.assigns.receipt_mode)

    socket
    |> assign(:receipt_rows, rows)
    |> assign(:receipt_valid?, valid?)
    |> assign(:receipt_error, error)
    |> assign(:receive_form, to_form(%{}, as: :receipt))
  end

  defp receipt_validation(rows, mode) do
    selected = Enum.filter(rows, & &1.included)

    cond do
      selected == [] ->
        {false, "Select at least one purchase order line to receive."}

      Enum.any?(selected, &invalid_lot_line?/1) ->
        {false, "Enter a supplier lot code and a positive quantity for every selected lot."}

      Enum.any?(selected, &Decimal.lt?(unassigned_quantity(&1), Decimal.new(0))) ->
        {false, "The assigned quantity cannot exceed the outstanding quantity."}

      mode == :all and Enum.any?(selected, &(not allocation_valid?(&1, :all))) ->
        {false, "Assign the full outstanding quantity for every line, or choose Partial delivery."}

      true ->
        {true, nil}
    end
  end

  defp invalid_lot_line?(row) do
    Enum.any?(row.lines, fn line ->
      String.trim(line.supplier_lot_code) == "" or not positive_decimal?(line.quantity)
    end)
  end

  defp assigned_quantity(%{included: false}), do: Decimal.new(0)

  defp assigned_quantity(row) do
    Enum.reduce(row.lines, Decimal.new(0), fn line, total ->
      Decimal.add(total, decimal_or_zero(line.quantity))
    end)
  end

  defp unassigned_quantity(row), do: Decimal.sub(row.remaining, assigned_quantity(row))

  defp allocation_valid?(%{included: false}, _mode), do: true

  defp allocation_valid?(row, :partial) do
    Decimal.gt?(assigned_quantity(row), Decimal.new(0)) and
      not Decimal.lt?(unassigned_quantity(row), Decimal.new(0))
  end

  defp allocation_valid?(row, :all), do: Decimal.equal?(unassigned_quantity(row), Decimal.new(0))

  defp decimal_or_zero(value) do
    Decimal.new(value || "0")
  rescue
    _ -> Decimal.new(0)
  end

  defp internal_lot_code(reference, row, line) do
    sequence =
      row.existing_lot_count
      |> Kernel.+(String.to_integer(line.key))
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "#{reference}-L#{row.po_line}-#{sequence}"
  end

  defp receipt_lot_count(rows) do
    rows
    |> Enum.filter(& &1.included)
    |> Enum.reduce(0, &(length(&1.lines) + &2))
  end

  defp receipt_success_message(:partial), do: "Partial delivery received with supplier lot traceability"

  defp receipt_success_message(:all), do: "Purchase order received with supplier lot traceability"

  defp positive_decimal?(value) when is_binary(value) do
    Decimal.gt?(Decimal.new(value), Decimal.new(0))
  rescue
    _ -> false
  end

  defp positive_decimal?(_), do: false

  defp unit_abbreviation(:gram), do: "g"
  defp unit_abbreviation(:kilogram), do: "kg"
  defp unit_abbreviation(:milliliter), do: "ml"
  defp unit_abbreviation(:liter), do: "l"
  defp unit_abbreviation(unit), do: to_string(unit)

  defp progress_percent(part, total) do
    if Decimal.gt?(total, Decimal.new(0)) do
      part
      |> Decimal.div(total)
      |> Decimal.mult(100)
      |> Decimal.to_float()
      |> max(0)
      |> min(100)
      |> Float.round(1)
    else
      0
    end
  end

  defp po_status_label(:partially_received), do: "Partially received"
  defp po_status_label(status), do: status |> to_string() |> String.capitalize()

  defp received_quantity(item) do
    Enum.reduce(item.lots || [], Decimal.new(0), fn lot, total ->
      Decimal.add(total, lot.received_quantity || Decimal.new(0))
    end)
  end
end
