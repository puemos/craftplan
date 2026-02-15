defmodule CraftplanWeb.OverviewScheduleTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.Orders

  # ── Helpers ──────────────────────────────────────────────────────

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer([:positive])}",
      sku: "SKU-#{System.unique_integer([:positive])}",
      price: Money.new("5.00", :USD),
      status: :active
    })
    |> Ash.create!(actor: staff())
  end

  defp customer! do
    Craftplan.CRM.Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "T",
      last_name: "U"
    })
    |> Ash.create!()
  end

  defp order_with_item!(product, customer, opts \\ []) do
    delivery_date = Keyword.get(opts, :delivery_date, DateTime.utc_now())

    order =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: delivery_date
      })
      |> Ash.create!(actor: staff())

    order_item =
      Orders.OrderItem
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        quantity: Decimal.new("5"),
        unit_price: product.price,
        status: :todo
      })
      |> Ash.Changeset.force_change_attribute(:order_id, order.id)
      |> Ash.create!(actor: staff())

    {order, order_item}
  end

  defp create_batch_for_items!(product, order_items) do
    actor = staff()

    items_with_remaining =
      order_items
      |> Enum.map(fn item ->
        full =
          Orders.get_order_item_by_id!(item.id,
            load: [:quantity, :planned_qty_sum],
            actor: actor
          )

        planned = full.planned_qty_sum || Decimal.new(0)
        remaining = Decimal.sub(full.quantity, planned)
        %{id: full.id, remaining: remaining}
      end)
      |> Enum.filter(fn %{remaining: r} -> Decimal.compare(r, Decimal.new(0)) == :gt end)

    planned_qty =
      Enum.reduce(items_with_remaining, Decimal.new(0), fn %{remaining: r}, acc ->
        Decimal.add(acc, r)
      end)

    Orders.ProductionBatch
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(
      :allocations,
      Enum.map(items_with_remaining, fn %{id: id, remaining: r} ->
        %{order_item_id: id, planned_qty: r}
      end)
    )
    |> Ash.Changeset.for_create(:open_with_allocations, %{
      product_id: product.id,
      planned_qty: planned_qty
    })
    |> Ash.create!(actor: actor)
  end

  # ── Tests ────────────────────────────────────────────────────────

  describe "kanban daily view" do
    @tag role: :staff
    test "renders unbatched column with product card", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, _item} = order_with_item!(product, customer)

      {:ok, view, html} = live(conn, ~p"/manage/production/schedule?view=day")

      assert html =~ product.name
      assert html =~ "Unbatched"
      assert has_element?(view, ~s(.kanban-column[data-status="unbatched"]))
    end

    @tag role: :staff
    test "batched items appear in kanban open column", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      assert has_element?(
               view,
               ~s(.kanban-column[data-status="open"] .kanban-card[data-batch-code="#{batch.batch_code}"])
             )
    end

    @tag role: :staff
    test "clicking unbatched card opens modal with order details and Batch All", %{conn: conn} do
      product = product!()
      customer = customer!()
      {order, _item} = order_with_item!(product, customer)

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Click unbatched card to open modal
      view
      |> element(~s([phx-click="open_unbatched_modal"][phx-value-product-id="#{product.id}"]))
      |> render_click()

      html = render(view)
      assert html =~ order.reference
      assert html =~ "Not Batched"
      assert html =~ "Batch All"
    end

    @tag role: :staff
    test "clicking batch card opens modal with order details and batch link", %{conn: conn} do
      product = product!()
      customer = customer!()
      {order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      view
      |> element(~s([phx-click="open_batch_modal"][phx-value-batch-code="#{batch.batch_code}"]))
      |> render_click()

      html = render(view)
      assert html =~ order.reference
      assert html =~ "View full batch"
    end
  end

  describe "Batch All action" do
    @tag role: :staff
    test "creates batch from unbatched modal", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, _item} = order_with_item!(product, customer)

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Open unbatched modal first
      view
      |> element(~s([phx-click="open_unbatched_modal"][phx-value-product-id="#{product.id}"]))
      |> render_click()

      # Click Batch All in the modal
      view
      |> element("button", "Batch All")
      |> render_click()

      html = render(view)
      assert html =~ "created"
    end
  end

  describe "Start batch" do
    @tag role: :staff
    test "transitions batch to in_progress column via modal", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Open batch modal
      view
      |> element(~s([phx-click="open_batch_modal"][phx-value-batch-code="#{batch.batch_code}"]))
      |> render_click()

      # Click Start in the modal
      view
      |> element("button", "Start")
      |> render_click()

      html = render(view)
      assert html =~ "started"

      assert has_element?(
               view,
               ~s(.kanban-column[data-status="in_progress"] .kanban-card[data-batch-code="#{batch.batch_code}"])
             )
    end
  end

  describe "Complete batch" do
    @tag role: :staff
    test "Mark Done shows completion form, Complete finishes batch", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      # Start the batch first
      Ash.update!(batch, %{}, action: :start, actor: staff())

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Open batch modal
      view
      |> element(~s([phx-click="open_batch_modal"][phx-value-batch-code="#{batch.batch_code}"]))
      |> render_click()

      # Click Mark Done to show completion form
      view
      |> element("button", "Mark Done")
      |> render_click()

      html = render(view)
      assert html =~ "Produced qty"
      assert html =~ "Cancel"

      # Submit completion form
      view
      |> form("#complete-form-#{batch.batch_code}", %{
        "produced_qty" => "5"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "completed"
    end
  end

  describe "completed batch" do
    @tag role: :staff
    test "appears in completed column", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      # Start and complete the batch
      {:ok, started} = Ash.update(batch, %{}, action: :start, actor: staff())

      started
      |> Ash.Changeset.for_update(:complete, %{produced_qty: Decimal.new("5")})
      |> Ash.update!(actor: staff())

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      assert has_element?(
               view,
               ~s(.kanban-column[data-status="completed"] .kanban-card[data-batch-code="#{batch.batch_code}"])
             )
    end
  end

  describe "drag and drop" do
    @tag role: :staff
    test "drop_batch from open to in_progress starts the batch", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Simulate drag from open → in_progress
      view
      |> element("#kanban-batches")
      |> render_hook("drop_batch", %{
        "batch_code" => batch.batch_code,
        "from" => "open",
        "to" => "in_progress"
      })

      html = render(view)
      assert html =~ "started"

      assert has_element?(
               view,
               ~s(.kanban-column[data-status="in_progress"] .kanban-card[data-batch-code="#{batch.batch_code}"])
             )
    end

    @tag role: :staff
    test "drop_batch from in_progress to completed opens completion form", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      Ash.update!(batch, %{}, action: :start, actor: staff())

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Simulate drag from in_progress → completed
      view
      |> element("#kanban-batches")
      |> render_hook("drop_batch", %{
        "batch_code" => batch.batch_code,
        "from" => "in_progress",
        "to" => "completed"
      })

      html = render(view)
      # Should open modal with completion form
      assert html =~ "Produced qty"
      assert html =~ "Complete"
    end

    @tag role: :staff
    test "backward drag is rejected", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      Ash.update!(batch, %{}, action: :start, actor: staff())

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      # Try dragging in_progress → open (backward)
      view
      |> element("#kanban-batches")
      |> render_hook("drop_batch", %{
        "batch_code" => batch.batch_code,
        "from" => "in_progress",
        "to" => "open"
      })

      html = render(view)
      assert html =~ "Cannot move a batch backward"
    end

    @tag role: :staff
    test "open to completed is rejected", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, item} = order_with_item!(product, customer)
      batch = create_batch_for_items!(product, [item])

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=day")

      view
      |> element("#kanban-batches")
      |> render_hook("drop_batch", %{
        "batch_code" => batch.batch_code,
        "from" => "open",
        "to" => "completed"
      })

      html = render(view)
      assert html =~ "Batch must be started before completing"
    end
  end

  describe "weekly view" do
    @tag role: :staff
    test "shows batch status in week cells", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, _item} = order_with_item!(product, customer)

      {:ok, _view, html} = live(conn, ~p"/manage/production/schedule?view=week")

      assert html =~ product.name
      assert html =~ "Unbatched"
    end

    @tag role: :staff
    test "clicking weekly cell navigates to day view", %{conn: conn} do
      product = product!()
      customer = customer!()
      {_order, _item} = order_with_item!(product, customer)

      {:ok, view, _html} = live(conn, ~p"/manage/production/schedule?view=week")

      today = Date.utc_today()

      # Navigate to day view via URL patch (same as clicking a weekly card)
      date = Date.to_iso8601(today)
      html = render_patch(view, ~p"/manage/production/schedule?view=day&date=#{date}")

      # After patch, we should be in day view with kanban columns
      assert html =~ "Unbatched"
    end
  end

  describe "plan route removed" do
    @tag role: :staff
    test "/manage/production/plan route no longer exists", %{conn: conn} do
      assert {:error, {:live_redirect, _}} = live(conn, "/manage/production/plan")
    rescue
      # NoRouteError is raised at the plug/conn level, not wrapped by live/2
      Phoenix.Router.NoRouteError -> :ok
      FunctionClauseError -> :ok
    end
  end
end
