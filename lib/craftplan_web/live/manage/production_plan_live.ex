defmodule CraftplanWeb.ProductionPlanLive do
  @moduledoc false
  use CraftplanWeb, :live_view

  import Ash.Expr

  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias Craftplan.Orders.ProductionBatch
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation
  alias Decimal, as: D

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:today, Date.utc_today())
     |> assign(:pending_items, [])
     |> assign(:selected_ids, MapSet.new())
     |> assign(:batches_by_status, %{open: [], in_progress: [], done: []})
     |> assign(:page_title, "Plan")
     |> assign(:show_batch_modal, false)
     |> assign(:batch_groups, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load_plan(socket)}
  end

  defp load_plan(socket) do
    actor = socket.assigns[:current_user]
    today = socket.assigns.today
    to = DateTime.new!(today, ~T[23:59:59], socket.assigns.time_zone)

    items =
      case Orders.list_order_items_for_plan(%{to: to}, actor: actor) do
        {:ok, items} ->
          items
          |> Enum.map(&add_remaining/1)
          |> Enum.filter(fn i -> D.compare(i.remaining, D.new(0)) == :gt end)
          |> Enum.sort_by(fn item -> item.order.delivery_date end)

        _ ->
          []
      end

    batches =
      case Orders.list_production_batches_for_plan(actor: actor) do
        {:ok, list} -> list
        _ -> []
      end

    socket
    |> assign(:pending_items, items)
    |> assign(:batches_by_status, categorize_batches(batches))
    |> Navigation.assign(:production, [
      Navigation.root(:production),
      Navigation.page(:production, :plan)
    ])
  end

  defp add_remaining(item) do
    completed = item.completed_qty_sum || D.new(0)
    remaining = D.sub(item.quantity, completed)
    Map.put(item, :remaining, remaining)
  end

  defp categorize_batches(batches) do
    groups = Enum.group_by(batches, & &1.status)

    %{
      open: Map.get(groups, :open, []),
      in_progress: Map.get(groups, :in_progress, []),
      done: Map.get(groups, :completed, [])
    }
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <Page.page>
      <.header>
        Production Plan
        <:subtitle>
          Pending items through today; add them to batches without leaving the page.
        </:subtitle>
        <:actions>
          <.button
            id="batch-button"
            variant={:primary}
            phx-click="prepare_batch_modal"
            disabled={MapSet.size(@selected_ids) == 0}
          >
            Add to Batch…
          </.button>
        </:actions>
      </.header>

      <Page.two_column>
        <:left>
          <Page.section>
            <Page.surface>
              <.table id="pending-items" rows={@pending_items}>
                <:empty>
                  <div class="rounded border border-dashed border-stone-200 bg-stone-50 py-8 text-center text-sm text-stone-500">
                    Nothing pending.
                  </div>
                </:empty>
                <:col :let={item} label="Select" align={:center}>
                  <input
                    type="checkbox"
                    value={item.id}
                    checked={MapSet.member?(@selected_ids, item.id)}
                    phx-click="toggle_select"
                    phx-value-id={item.id}
                  />
                </:col>
                <:col :let={item} label="Order">{format_reference(item.order.reference)}</:col>
                <:col :let={item} label="Product">{item.product.name}</:col>
                <:col :let={item} label="Customer">
                  {item.order.customer && item.order.customer.full_name}
                </:col>
                <:col :let={item} label="Qty">{item.quantity}</:col>
                <:col :let={item} label="Remaining">{item.remaining}</:col>
                <:col :let={item} label="Planned">{item.planned_qty_sum || D.new(0)}</:col>
              </.table>
            </Page.surface>
          </Page.section>
        </:left>
        <:right>
          <Page.section>
            <Page.surface class="space-y-6">
              <.batch_lane title="To Do" batches={@batches_by_status.open} />
              <.batch_lane title="In Progress" batches={@batches_by_status.in_progress} />
              <.batch_lane title="Done" batches={@batches_by_status.done} />
            </Page.surface>
          </Page.section>
        </:right>
      </Page.two_column>

      <.modal
        :if={@show_batch_modal}
        id="batch-plan-modal"
        show
        title="Add selected items to batches"
        on_cancel={JS.push("cancel_batch_modal")}
      >
        <.form id="plan-batch-form" for={%{}} phx-submit="confirm_batch_modal">
          <div class="space-y-4">
            <div :for={{group, index} <- Enum.with_index(@batch_groups)} class="space-y-2">
              <div class="text-sm font-semibold">{group.product.name}</div>
              <input type="hidden" name={"product_ids[#{index}]"} value={group.product_id} />
              <.input
                type="select"
                name={"targets[#{group.product_id}]"}
                label="Target"
                value="new"
                options={[
                  {"Create new batch", "new"}
                  | Enum.map(group.open_batches, fn batch ->
                      {"Add to #{batch.batch_code} (#{batch.status})", "existing:" <> batch.id}
                    end)
                ]}
              />
            </div>
            <div class="flex items-center justify-end gap-2">
              <.button variant={:outline} phx-click="cancel_batch_modal">Cancel</.button>
              <.button variant={:primary} type="submit">Confirm</.button>
            </div>
          </div>
        </.form>
      </.modal>
    </Page.page>
    """
  end

  defp batch_lane(assigns) do
    assigns = assign_new(assigns, :batches, fn -> [] end)

    ~H"""
    <div class="rounded border border-stone-200 p-4">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold">{@title}</span>
        <span class="text-xs text-stone-500">{length(@batches)} batches</span>
      </div>
      <div class="mt-3 space-y-3">
        <div :if={Enum.empty?(@batches)} class="text-xs text-stone-400">No batches</div>
        <.batch_card :for={batch <- @batches} batch={batch} />
      </div>
    </div>
    """
  end

  defp batch_card(assigns) do
    assigns = assign_new(assigns, :batch, fn -> nil end)

    ~H"""
    <div class="rounded border border-stone-200 bg-white p-3">
      <div class="text-sm font-semibold">{@batch.batch_code}</div>
      <div class="text-xs text-stone-500">{@batch.product && @batch.product.name}</div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, selected_ids)}
  end

  @impl true
  def handle_event("prepare_batch_modal", _params, socket) do
    selected = socket.assigns.selected_ids

    if MapSet.size(selected) == 0 do
      {:noreply, put_flash(socket, :info, "Nothing selected")}
    else
      items = Enum.filter(socket.assigns.pending_items, &MapSet.member?(selected, &1.id))
      groups = Enum.group_by(items, & &1.product_id)

      batch_groups =
        Enum.map(groups, fn {product_id, grouped_items} ->
          open = Enum.filter(socket.assigns.batches_by_status.open, &(&1.product_id == product_id))

          %{
            product_id: product_id,
            product: grouped_items |> hd() |> Map.get(:product),
            items: grouped_items,
            open_batches: open
          }
        end)

      {:noreply,
       socket
       |> assign(:batch_groups, batch_groups)
       |> assign(:show_batch_modal, true)}
    end
  end

  @impl true
  def handle_event("confirm_batch_modal", %{"targets" => targets}, socket) do
    actor = socket.assigns[:current_user]

    results =
      Enum.map(socket.assigns.batch_groups, fn group ->
        case Map.get(targets, group.product_id) do
          "new" -> create_batch(group, actor)
          "existing:" <> batch_id -> add_to_batch(group, batch_id, actor)
          _ -> {:error, :invalid_target}
        end
      end)

    {oks, errs} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    socket =
      case {oks, errs} do
        {_, []} ->
          codes = Enum.map_join(oks, ", ", fn {:ok, code} -> code end)

          socket
          |> put_flash(:info, "Created/updated batches: #{codes}")
          |> assign(:selected_ids, MapSet.new())
          |> assign(:show_batch_modal, false)
          |> assign(:batch_groups, [])
          |> load_plan()

        {_, _} ->
          socket
          |> put_flash(:warning, "Some operations failed")
          |> assign(:show_batch_modal, false)
      end

    {:noreply, socket}
  end

  def handle_event("confirm_batch_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_batch_modal", _params, socket) do
    {:noreply, assign(socket, show_batch_modal: false, batch_groups: [])}
  end

  defp create_batch(group, actor) do
    allocations =
      Enum.map(group.items, fn item ->
        %{order_item_id: item.id, planned_qty: item.remaining}
      end)

    planned = Enum.reduce(allocations, D.new(0), fn a, acc -> D.add(acc, a.planned_qty) end)

    changeset =
      ProductionBatch
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:allocations, allocations)
      |> Ash.Changeset.for_create(:open_with_allocations, %{
        product_id: group.product_id,
        planned_qty: planned
      })

    case Ash.create(changeset, actor: actor) do
      {:ok, batch} -> {:ok, batch.batch_code}
      {:error, err} -> {:error, err}
    end
  end

  defp add_to_batch(group, batch_id, actor) do
    Enum.reduce_while(group.items, {:ok, batch_id}, fn item, _acc ->
      qty = item.remaining

      existing =
        OrderItemBatchAllocation
        |> Ash.Query.new()
        |> Ash.Query.filter(expr(order_item_id == ^item.id and production_batch_id == ^batch_id))
        |> Ash.read_one(actor: actor)

      case existing do
        {:ok, alloc} ->
          Ash.update!(alloc, %{planned_qty: D.add(alloc.planned_qty || D.new(0), qty)},
            action: :update,
            actor: actor
          )

          {:cont, {:ok, batch_id}}

        nil ->
          changeset =
            Ash.Changeset.for_create(OrderItemBatchAllocation, :create, %{
              order_item_id: item.id,
              production_batch_id: batch_id,
              planned_qty: qty,
              completed_qty: D.new(0)
            })

          case Ash.create(changeset, actor: actor) do
            {:ok, _} -> {:cont, {:ok, batch_id}}
            {:error, err} -> {:halt, {:error, err}}
          end

        _ ->
          {:halt, {:error, :unexpected}}
      end
    end)
  end
end
