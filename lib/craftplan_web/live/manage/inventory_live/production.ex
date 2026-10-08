defmodule CraftplanWeb.InventoryLive.Production do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias AshPhoenix.FormData.Error
  alias Craftplan.Inventory
  alias Craftplan.Inventory.Intermediates
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialBatch
  alias Craftplan.Inventory.MaterialRecipe
  alias Craftplan.Types.Unit
  alias CraftplanWeb.Components.MaterialDetail
  alias CraftplanWeb.Navigation
  alias Decimal, as: D

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(modal: nil, error: nil)
     |> stream_configure(:batches, dom_id: &"material-batches-#{&1.id}")}
  end

  @impl true
  def handle_params(%{"sku" => sku}, _uri, socket) do
    actor = socket.assigns.current_user
    material = Inventory.get_material_by_sku!(sku, load: [:current_stock], actor: actor)

    materials =
      Material
      |> Ash.Query.filter(id != ^material.id)
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(actor: actor)

    {:noreply,
     socket
     |> assign(material: material, materials: materials, page_title: "Material Production")
     |> reload_production()
     |> Navigation.assign(:inventory, [
       Navigation.root(:inventory),
       Navigation.resource(:material, material),
       Navigation.page(:inventory, :material_production, material)
     ])}
  end

  defp reload_production(socket) do
    actor = socket.assigns.current_user
    material = Ash.reload!(socket.assigns.material, load: [:current_stock], actor: actor)
    batches = Intermediates.batches(material.id, actor)

    socket
    |> assign(
      material: material,
      recipe: Intermediates.latest_recipe(material.id, actor),
      batch_count: length(batches)
    )
    |> stream(:batches, batches, reset: true)
  end

  @impl true
  def handle_event("edit_recipe", _, socket) do
    recipe = socket.assigns.recipe

    rows =
      if recipe,
        do: Enum.map(recipe.components, &Map.take(&1, ["material_id", "quantity"])),
        else: [%{"material_id" => "", "quantity" => ""}, %{"material_id" => "", "quantity" => ""}]

    params = %{
      "yield_quantity" => if(recipe, do: D.to_string(recipe.yield_quantity, :normal), else: "1000"),
      "notes" => if(recipe, do: recipe.notes || "", else: ""),
      "components" => index_rows(rows)
    }

    {:noreply, socket |> assign(modal: :recipe, error: nil) |> recipe_form(params)}
  end

  def handle_event("change_recipe", %{"recipe" => params}, socket), do: {:noreply, recipe_form(socket, params)}

  def handle_event("add_component", _, socket) do
    params = socket.assigns.recipe_form.params
    rows = ordered_rows(params["components"]) ++ [%{"material_id" => "", "quantity" => ""}]
    {:noreply, recipe_form(socket, Map.put(params, "components", index_rows(rows)))}
  end

  def handle_event("remove_component", %{"index" => index}, socket) do
    params = socket.assigns.recipe_form.params
    rows = params["components"] |> ordered_rows() |> List.delete_at(String.to_integer(index))
    {:noreply, recipe_form(socket, Map.put(params, "components", index_rows(rows)))}
  end

  def handle_event("save_recipe", %{"recipe" => params}, socket) do
    attrs = %{
      material_id: socket.assigns.material.id,
      yield_quantity: params["yield_quantity"],
      notes: params["notes"],
      components: ordered_rows(params["components"])
    }

    case MaterialRecipe
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(modal: nil, error: nil)
         |> reload_production()
         |> put_flash(:info, "Recipe saved. Future batches use this version.")}

      {:error, error} ->
        {:noreply, socket |> recipe_form(params) |> assign(error: error_message(error))}
    end
  end

  def handle_event("make_batch", _, %{assigns: %{recipe: nil}} = socket), do: {:noreply, socket}

  def handle_event("make_batch", _, socket) do
    recipe = socket.assigns.recipe

    lots =
      Map.new(recipe.components, fn c ->
        available =
          %{material_id: c["material_id"]}
          |> Inventory.list_available_lots_for_material!(actor: socket.assigns.current_user)
          |> Enum.reject(&(&1.expiry_date && Date.before?(&1.expiry_date, Date.utc_today())))

        {c["material_id"], available}
      end)

    params = %{
      "planned_quantity" => D.to_string(recipe.yield_quantity, :normal),
      "actual_quantity" => D.to_string(recipe.yield_quantity, :normal),
      "lot_code" => "MAKE-#{Date.utc_today()}-#{String.upcase(String.slice(Ash.UUID.generate(), 0, 6))}",
      "expiry_date" => "",
      "notes" => ""
    }

    {:noreply,
     socket
     |> assign(
       modal: :batch,
       error: nil,
       lots: lots,
       batch_step: :plan,
       editing_lots: MapSet.new()
     )
     |> batch_form(Map.put(params, "inputs", suggested_inputs(recipe, lots, recipe.yield_quantity)))}
  end

  def handle_event("change_batch", %{"batch" => params}, socket) do
    old = socket.assigns.batch_form.params
    params = Map.merge(old, params)

    params =
      if params["planned_quantity"] == old["planned_quantity"] do
        params
      else
        case positive_decimal(params["planned_quantity"]) do
          {:ok, target} ->
            params
            |> Map.put(
              "actual_quantity",
              if(old["actual_quantity"] == old["planned_quantity"],
                do: params["planned_quantity"],
                else: params["actual_quantity"]
              )
            )
            |> Map.put(
              "inputs",
              suggested_inputs(socket.assigns.recipe, socket.assigns.lots, target)
            )

          _ ->
            params
        end
      end

    {:noreply, batch_form(socket, params)}
  end

  def handle_event("review_batch", %{"batch" => params}, socket) do
    {:noreply,
     socket
     |> batch_form(Map.merge(socket.assigns.batch_form.params, params))
     |> assign(batch_step: :result, error: nil, editing_lots: MapSet.new())}
  end

  def handle_event("back_to_plan", _, socket), do: {:noreply, assign(socket, batch_step: :plan, error: nil)}

  def handle_event("edit_input_lot", %{"index" => index}, socket) do
    editing_lots = socket.assigns.editing_lots

    editing_lots =
      if MapSet.member?(editing_lots, index),
        do: MapSet.delete(editing_lots, index),
        else: MapSet.put(editing_lots, index)

    {:noreply, assign(socket, editing_lots: editing_lots)}
  end

  def handle_event("add_lot", %{"material-id" => material_id}, socket) do
    params = socket.assigns.batch_form.params

    rows =
      ordered_rows(params["inputs"]) ++
        [%{"material_id" => material_id, "lot_id" => "", "quantity" => ""}]

    {:noreply,
     socket
     |> batch_form(Map.put(params, "inputs", index_rows(rows)))
     |> assign(editing_lots: MapSet.put(socket.assigns.editing_lots, to_string(length(rows) - 1)))}
  end

  def handle_event("remove_lot", %{"index" => index}, socket) do
    params = socket.assigns.batch_form.params
    rows = params["inputs"] |> ordered_rows() |> List.delete_at(String.to_integer(index))
    {:noreply, batch_form(socket, Map.put(params, "inputs", index_rows(rows)))}
  end

  def handle_event("complete_batch", %{"batch" => params}, %{assigns: %{batch_step: :plan}} = socket),
    do: handle_event("review_batch", %{"batch" => params}, socket)

  def handle_event("complete_batch", %{"batch" => params}, socket) do
    attrs = %{
      material_id: socket.assigns.material.id,
      recipe_id: socket.assigns.recipe.id,
      planned_quantity: params["planned_quantity"],
      actual_quantity: params["actual_quantity"],
      lot_code: params["lot_code"],
      expiry_date: blank_to_nil(params["expiry_date"]),
      notes: params["notes"],
      inputs: ordered_rows(params["inputs"])
    }

    case MaterialBatch
         |> Ash.Changeset.for_create(:produce, attrs)
         |> Ash.create(actor: socket.assigns.current_user) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> assign(modal: nil, error: nil)
         |> reload_production()
         |> put_flash(:info, "#{batch.lot_code} completed. Inputs consumed and output stocked.")}

      {:error, error} ->
        {:noreply, socket |> batch_form(params) |> assign(error: error_message(error))}
    end
  end

  def handle_event("close_modal", _, socket), do: {:noreply, assign(socket, modal: nil, error: nil)}

  defp recipe_form(socket, params),
    do: assign(socket, recipe_form: to_form(params, as: :recipe), recipe_rows: ordered_rows(params["components"]))

  defp batch_form(socket, params),
    do: assign(socket, batch_form: to_form(params, as: :batch), input_rows: ordered_rows(params["inputs"]))

  defp index_rows(rows), do: rows |> Enum.with_index() |> Map.new(fn {row, i} -> {to_string(i), row} end)

  defp ordered_rows(nil), do: []

  defp ordered_rows(rows), do: rows |> Enum.sort_by(fn {key, _} -> String.to_integer(key) end) |> Enum.map(&elem(&1, 1))

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp error_message(error) do
    error
    |> Ash.Error.to_error_class()
    |> Map.get(:errors, [])
    |> Enum.flat_map(fn error ->
      if Error.impl_for(error) do
        error
        |> Error.to_form_error()
        |> List.wrap()
        |> Enum.map(fn {field, message, vars} ->
          message =
            Enum.reduce(vars || [], message || "is invalid", fn {key, value}, text ->
              String.replace(text, "%{#{key}}", to_string(value))
            end)

          if field == :inputs or field == :components,
            do: message,
            else: "#{field |> to_string() |> String.replace("_", " ") |> String.capitalize()}: #{message}"
        end)
      else
        ["Unable to save this record. Check your selections and try again."]
      end
    end)
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  defp positive_decimal(value) do
    case D.parse(value || "") do
      {d, ""} -> if D.gt?(d, 0), do: {:ok, d}, else: :error
      _ -> :error
    end
  end

  defp suggested_inputs(recipe, lots, target) do
    recipe.components
    |> Enum.flat_map(fn c ->
      needed = D.mult(D.new(c["quantity"]), D.div(target, recipe.yield_quantity))

      {rows, remaining} =
        Enum.reduce_while(lots[c["material_id"]], {[], needed}, fn lot, {rows, remaining} ->
          if D.lte?(remaining, 0),
            do: {:halt, {rows, remaining}},
            else:
              (
                take = D.min(lot.current_stock, remaining)

                {:cont,
                 {rows ++
                    [
                      %{
                        "material_id" => c["material_id"],
                        "lot_id" => lot.id,
                        "quantity" => D.to_string(take, :normal)
                      }
                    ], D.sub(remaining, take)}}
              )
        end)

      if D.gt?(remaining, 0),
        do:
          rows ++
            [
              %{
                "material_id" => c["material_id"],
                "lot_id" => "",
                "quantity" => D.to_string(remaining, :normal)
              }
            ],
        else: rows
    end)
    |> index_rows()
  end

  defp component(recipe, material_id), do: Enum.find(recipe.components, &(&1["material_id"] == material_id))

  defp lot_options(lots, material_id, unit),
    do: Enum.map(lots[material_id] || [], &{"#{&1.lot_code} · #{format_amount(unit, &1.current_stock)} available", &1.id})

  defp unit(c), do: String.to_existing_atom(c["unit"])

  defp lot_cost_rate(cost, unit, currency) do
    basis = if unit in [:gram, :milliliter], do: D.new(1000), else: D.new(1)
    "#{format_money(currency, D.mult(cost, basis))} / #{format_amount(unit, basis)}"
  end

  defp preview_cost(rows, lots, materials, currency) do
    result =
      Enum.reduce_while(rows, {:ok, D.new(0)}, fn row, {:ok, total} ->
        lot = Enum.find(lots[row["material_id"]] || [], &(&1.id == row["lot_id"]))
        material = Enum.find(materials, &(&1.id == row["material_id"]))

        with %{id: _} <- lot, {:ok, quantity} <- positive_decimal(row["quantity"]) do
          {:cont, {:ok, D.add(total, D.mult(quantity, lot.unit_cost || material.price))}}
        else
          _ -> {:halt, :error}
        end
      end)

    case result do
      {:ok, cost} -> format_money(currency, cost)
      _ -> "Choose input lots"
    end
  end

  defp input_summary(rows, recipe) do
    Enum.map_join(rows, " + ", fn row ->
      c = component(recipe, row["material_id"])
      "#{row["quantity"]} #{c["unit"]} #{c["name"]}"
    end)
  end

  defp yield_percent(actual, planned) do
    with {:ok, actual} <- positive_decimal(actual), {:ok, planned} <- positive_decimal(planned) do
      actual |> D.div(planned) |> D.mult(100) |> D.round(1) |> D.to_string(:normal)
    else
      _ -> "—"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <MaterialDetail.material_header material={@material} active={:production}>
      <:actions>
        <.link navigate={~p"/manage/inventory/#{@material.sku}/edit"}>
          <.button>Edit</.button>
        </.link>
        <.link navigate={~p"/manage/inventory/#{@material.sku}/adjust"}>
          <.button variant={:primary}>Adjust Stock</.button>
        </.link>
      </:actions>
    </MaterialDetail.material_header>

    <div class="mt-4 space-y-6">
      <.tabs_content>
        <div class="space-y-6">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0 flex-1">
              <h2 class="text-base font-semibold text-stone-900">Production</h2>
              <p class="mt-1 text-sm text-stone-500">
                Make this material in-house, then use its stock in finished products.
              </p>
            </div>
            <.button
              id="make-material-batch"
              variant={:primary}
              phx-click="make_batch"
              disabled={is_nil(@recipe)}
            >
              Make batch
            </.button>
          </div>
          <div
            id="material-production-summary"
            class="flex flex-wrap items-center justify-between gap-4 border-b border-stone-200 pb-6"
          >
            <div class="flex items-baseline gap-2">
              <p id="produced-material-stock" class="text-lg font-semibold text-stone-900">
                {format_amount(@material.unit, @material.current_stock || D.new(0))}
              </p>
              <span class="text-sm text-stone-500">in stock</span>
            </div>
            <p class="text-sm text-stone-500">
              {if @recipe,
                do:
                  "#{format_amount(@material.unit, @recipe.yield_quantity)} standard batch · Recipe v#{@recipe.version}",
                else: "Add a recipe to start"}
              <span class="mx-2 text-stone-300">/</span>{@batch_count} completed
            </p>
          </div>
          <div class="space-y-6">
            <section
              id="material-recipe"
              class="space-y-4"
            >
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 class="font-semibold text-stone-900">Production recipe</h2><p class="mt-1 text-xs text-stone-500">
                    {if @recipe,
                      do:
                        "Inputs for #{format_amount(@material.unit, @recipe.yield_quantity)} of #{@material.name}",
                      else: "Turn input materials into stocked output"}
                  </p>
                </div>
                <.button id="edit-material-recipe" variant={:outline} phx-click="edit_recipe">{if @recipe,
                  do: "Edit recipe",
                  else: "Add recipe"}</.button>
              </div>
              <div :if={!@recipe} class="px-6 py-10 text-center">
                <.icon name="hero-beaker" class="mx-auto h-8 w-8 text-stone-400" />
                <h3 class="mt-3 text-sm font-semibold text-stone-900">Give this material a recipe</h3>
                <p class="mt-2 text-sm leading-6 text-stone-500">
                  Choose its input materials and standard yield. Make batches whenever you need more stock.
                </p>
              </div>
              <.table
                :if={@recipe}
                id="material-recipe-ingredients"
                no_margin
                rows={@recipe.components}
              >
                <:col :let={c} label="Ingredient">
                  <.link
                    navigate={
                      ~p"/manage/inventory/#{Enum.find(@materials, &(&1.id == c["material_id"])).sku}"
                    }
                    class="hover:underline"
                  >{c["name"]}</.link>
                </:col>
                <:col :let={c} label="Quantity" align={:right}>
                  {format_amount(unit(c), D.new(c["quantity"]))}
                </:col>
              </.table>
              <div :if={@recipe} class="space-y-2">
                <p :if={@recipe.notes && @recipe.notes != ""} class="mb-2 text-sm text-stone-600">
                  {@recipe.notes}
                </p>
                <p class="text-xs leading-5 text-stone-500">
                  Recipe changes apply to future batches. Completed batches keep the recipe and input lots used at the time.
                </p>
              </div>
            </section>
            <section>
              <div class="mb-4">
                <h2 class="font-semibold text-stone-900">Production history</h2><p class="mt-1 text-sm text-stone-500">
                  Actual yield, input lots, and stock from every batch.
                </p>
              </div>
              <div id="material-batches" phx-update="stream" class="space-y-3">
                <div
                  id="material-batches-empty"
                  class="hidden rounded-md border border-dashed border-stone-300 bg-stone-50 px-6 py-12 text-center only:block"
                >
                  <p class="text-sm font-medium text-stone-700">Your first batch starts here</p><p class="mt-2 text-sm text-stone-500">
                    Complete a batch to create stock and its lot history.
                  </p>
                </div>
                <details
                  :for={{id, batch} <- @streams.batches}
                  id={id}
                  class="group border-gray-200/70 rounded-md border bg-white"
                >
                  <summary class="flex cursor-pointer list-none items-center justify-between gap-3 p-5">
                    <div>
                      <p class="font-mono text-sm font-semibold text-stone-900">{batch.lot_code}</p><p class="mt-1 text-xs text-stone-500">
                        {format_time(batch.completed_at, @time_zone)} · Recipe v{batch.recipe_snapshot[
                          "version"
                        ]}
                      </p>
                    </div>
                    <div class="text-right">
                      <p class="text-sm font-semibold text-stone-900">
                        {format_amount(@material.unit, batch.actual_quantity)} made
                      </p><p class="mt-1 text-xs text-emerald-700">
                        {format_amount(@material.unit, batch.output_lot.current_stock || D.new(0))} on hand
                      </p>
                    </div>
                    <p class="hidden text-sm text-stone-500 sm:block">
                      {format_money(@settings.currency, batch.total_cost)}
                    </p>
                    <.icon
                      name="hero-chevron-down"
                      class="h-4 w-4 shrink-0 text-stone-400 group-open:rotate-180"
                    />
                  </summary>
                  <div class="border-t border-stone-100 px-5 pt-4 pb-5">
                    <div class="mb-4 grid grid-cols-2 gap-3 text-xs sm:grid-cols-4">
                      <div class="text-stone-500">
                        Yield<p class="mt-1 font-semibold text-stone-900">
                          {yield_percent(
                            D.to_string(batch.actual_quantity),
                            D.to_string(batch.planned_quantity)
                          )}% of plan
                        </p>
                      </div><div class="text-stone-500">
                        Input cost<p class="mt-1 font-semibold text-stone-900">
                          {format_money(@settings.currency, batch.total_cost)}
                        </p>
                      </div><div class="text-stone-500">
                        Output cost<p class="mt-1 font-semibold text-stone-900">
                          {lot_cost_rate(
                            batch.output_lot.unit_cost,
                            @material.unit,
                            @settings.currency
                          )}
                        </p>
                      </div><div class="text-stone-500">
                        Expires<p class="mt-1 font-semibold text-stone-900">
                          {batch.expiry_date || "No expiry"}
                        </p>
                      </div>
                    </div>
                    <p class="mb-2 text-xs font-medium uppercase tracking-wide text-stone-500">
                      Inputs consumed
                    </p>
                    <div
                      :for={input <- batch.inputs}
                      class="flex justify-between gap-3 border-b border-stone-100 py-2 text-sm"
                    >
                      <div class="text-stone-700">
                        {input.lot.material.name}
                        <p class="font-mono mt-1 text-xs text-stone-500">{input.lot.lot_code}</p>
                      </div><p class="font-medium text-stone-700">
                        {format_amount(input.lot.material.unit, input.quantity)}
                      </p>
                    </div>
                    <p :if={batch.notes && batch.notes != ""} class="mt-3 text-sm text-stone-500">
                      {batch.notes}
                    </p>
                    <.link
                      navigate={
                        ~p"/manage/production/traceability?#{%{mode: :forward, q: batch.lot_code}}"
                      }
                      class="mt-4 inline-flex items-center gap-2 text-sm font-medium text-indigo-700"
                    >Trace output lot <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
                  </div>
                </details>
              </div>
            </section>
          </div>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@modal == :recipe}
      id="material-recipe-modal"
      class="max-h-[calc(100dvh-2rem)] overflow-y-auto"
      title={if @recipe, do: "Edit production recipe", else: "Add production recipe"}
      show
      on_cancel={JS.push("close_modal")}
    >
      <.form
        for={@recipe_form}
        id="material-recipe-form"
        phx-change="change_recipe"
        phx-submit="save_recipe"
        class="space-y-5"
      >
        <p class="text-sm leading-6 text-stone-500">
          Define one standard batch of {@material.name}. Quantities scale when you make a larger or smaller batch.
        </p>
        <.input
          field={@recipe_form[:yield_quantity]}
          type="number"
          min="0.000001"
          step="any"
          required
          label={"Standard yield (#{@material.unit})"}
        />
        <div>
          <p class="mb-3 text-sm font-semibold text-stone-900">Input materials</p>
          <.table
            id="recipe-inputs"
            rows={Enum.with_index(@recipe_rows)}
            row_id={fn {_row, i} -> "recipe-input-#{i}" end}
            no_margin
            layout={:fixed}
            table_class="w-full min-w-[32rem]"
            wrapper_class="!px-0"
          >
            <:col :let={{row, i}} label="Material">
              <div class="border-b border-dashed border-stone-300 focus-within:border-stone-500">
                <.input
                  type="select"
                  flat
                  id={"recipe-material-#{i}"}
                  name={"recipe[components][#{i}][material_id]"}
                  value={row["material_id"]}
                  aria-label={"Material #{i + 1}"}
                  prompt="Choose material"
                  options={Enum.map(@materials, &{&1.name, &1.id})}
                  required
                />
              </div>
            </:col>
            <:col :let={{row, i}} label="Quantity" class="w-24 sm:w-32">
              <% material = Enum.find(@materials, &(&1.id == row["material_id"])) %>
              <div class="border-b border-dashed border-stone-300 focus-within:border-stone-500">
                <.input
                  type="number"
                  flat
                  id={"recipe-quantity-#{i}"}
                  name={"recipe[components][#{i}][quantity]"}
                  value={row["quantity"]}
                  aria-label={"Quantity for material #{i + 1}"}
                  inline_label={material && Unit.abbreviation(material.unit)}
                  min="0.000001"
                  step="any"
                  required
                />
              </div>
            </:col>
            <:col :let={{_row, i}} label="" class="w-20 sm:w-24">
              <button
                type="button"
                phx-click="remove_component"
                phx-value-index={i}
                aria-label="Remove input"
                class="cursor-pointer font-semibold text-stone-900 hover:text-stone-700"
              >Remove</button>
            </:col>
          </.table>
          <.button
            id="add-recipe-input"
            type="button"
            variant={:outline}
            phx-click="add_component"
            class="mt-3"
          ><.icon
            name="hero-plus"
            class="h-4 w-4"
          /> Add input</.button>
        </div>
        <.input
          field={@recipe_form[:notes]}
          type="textarea"
          label="Method or notes (optional)"
          rows="2"
        />
        <p
          :if={@error}
          id="recipe-error"
          role="alert"
          class="whitespace-pre-line rounded-lg bg-rose-50 p-3 text-sm text-rose-700"
        >
          {@error}
        </p>
        <div class="flex items-center justify-end gap-2 border-t border-stone-200 pt-4">
          <.button type="button" variant={:outline} phx-click="close_modal">Cancel</.button><.button
            id="save-material-recipe"
            type="submit"
            variant={:primary}
            phx-disable-with="Saving…"
          >Save recipe</.button>
        </div>
      </.form>
    </.modal>

    <.modal
      :if={@modal == :batch}
      id="material-batch-modal"
      class="max-h-[calc(100dvh-2rem)] overflow-y-auto"
      title={"Make #{@material.name}"}
      show
      on_cancel={JS.push("close_modal")}
    >
      <.form
        for={@batch_form}
        id="material-batch-form"
        phx-change="change_batch"
        phx-submit={if @batch_step == :plan, do: "review_batch", else: "complete_batch"}
        class="space-y-4"
      >
        <ol aria-label="Batch steps" class="flex items-center gap-3 text-xs">
          <li
            class={
              if @batch_step == :plan, do: "font-semibold text-indigo-700", else: "text-stone-500"
            }
            aria-current={if @batch_step == :plan, do: "step"}
          >
            1. Plan batch
          </li>
          <li aria-hidden="true" class="text-stone-300">/</li>
          <li
            class={
              if @batch_step == :result, do: "font-semibold text-indigo-700", else: "text-stone-500"
            }
            aria-current={if @batch_step == :result, do: "step"}
          >
            2. Record result
          </li>
        </ol>
        <div id="batch-plan-step" class={[@batch_step != :plan && "hidden"]}>
          <.input
            field={@batch_form[:planned_quantity]}
            type="number"
            min="0.000001"
            step="any"
            required
            label={"How much do you plan to make? (#{@material.unit})"}
          />
          <p class="mt-2 text-xs text-stone-500">
            Ingredients scale from recipe v{@recipe.version}. Stock changes only when you complete the batch.
          </p>
        </div>
        <div id="batch-result-step" class={[@batch_step != :result && "hidden"]}>
          <.input
            field={@batch_form[:actual_quantity]}
            type="number"
            min="0.000001"
            step="any"
            required
            label={"How much did you make? (#{@material.unit})"}
          />
          <p class="mt-2 text-xs text-stone-500">
            Planned: {@batch_form[:planned_quantity].value} {@material.unit}. Record the usable output, after any loss.
          </p>
        </div>
        <section aria-label="Batch ingredients">
          <div class="mb-2 flex items-center justify-between gap-2">
            <h3 class="text-sm font-semibold text-stone-900">
              {if @batch_step == :plan, do: "Ingredients", else: "Ingredients used"}
            </h3>
            <span class="text-xs text-stone-500">{if @batch_step == :plan,
              do: "Earliest expiry first",
              else: "Adjust to match actual use"}</span>
          </div>
          <.table
            id="batch-inputs"
            variant={:compact}
            rows={Enum.with_index(@input_rows)}
            row_id={fn {_row, i} -> "batch-ingredient-#{i}" end}
            no_margin
            layout={:fixed}
            table_class="w-full min-w-[24rem]"
            wrapper_class="!px-0"
          >
            <:col :let={{row, i}} label="Material">
              <% c = component(@recipe, row["material_id"]) %>
              <% lot = Enum.find(@lots[row["material_id"]] || [], &(&1.id == row["lot_id"])) %>
              <% editing? = MapSet.member?(@editing_lots, to_string(i)) || is_nil(lot) %>
              <input
                type="hidden"
                name={"batch[inputs][#{i}][material_id]"}
                value={row["material_id"]}
              />
              <p class="text-sm text-stone-900">{c["name"]}</p>
              <p :if={lot} class="font-mono mt-1 break-all text-xs text-stone-500">
                {lot.lot_code}
              </p>
              <button
                :if={lot}
                id={"change-input-lot-#{i}"}
                type="button"
                phx-click="edit_input_lot"
                phx-value-index={i}
                class="mt-1 text-xs font-medium text-indigo-600 hover:text-indigo-800"
              >{if editing?, do: "Done", else: "Change lot"}</button>
              <button
                :if={Enum.count(@input_rows, &(&1["material_id"] == row["material_id"])) > 1}
                type="button"
                phx-click="remove_lot"
                phx-value-index={i}
                aria-label="Remove lot"
                class="ml-2 text-xs font-semibold text-stone-900 hover:text-stone-700"
              >Remove</button>
              <div id={"batch-lot-options-#{i}"} class={["mt-3", !editing? && "hidden"]}>
                <div class="border-b border-dashed border-stone-300 focus-within:border-stone-500">
                  <.input
                    type="select"
                    flat
                    id={"batch-lot-#{i}"}
                    name={"batch[inputs][#{i}][lot_id]"}
                    value={row["lot_id"]}
                    aria-label={"Input lot for #{c["name"]}, row #{i + 1}"}
                    prompt="Choose lot"
                    options={lot_options(@lots, row["material_id"], unit(c))}
                    required
                  />
                </div>
                <p :if={@lots[row["material_id"]] == []} class="mt-2 text-xs text-rose-600">
                  No available stock lots. Receive this input before producing.
                </p>
                <button
                  type="button"
                  id={"split-input-lot-#{i}"}
                  phx-click="add_lot"
                  phx-value-material-id={row["material_id"]}
                  class="mt-2 text-xs font-medium text-indigo-600 hover:text-indigo-800"
                >Split across lots</button>
              </div>
            </:col>
            <:col
              :let={{row, i}}
              label={if @batch_step == :plan, do: "Quantity", else: "Used"}
              class="w-36"
            >
              <% c = component(@recipe, row["material_id"]) %>
              <div class="border-b border-dashed border-stone-300 focus-within:border-stone-500">
                <.input
                  type="number"
                  flat
                  id={"batch-input-quantity-#{i}"}
                  name={"batch[inputs][#{i}][quantity]"}
                  value={row["quantity"]}
                  aria-label={"#{if @batch_step == :plan, do: "Quantity", else: "Used"} for #{c["name"]}, row #{i + 1}"}
                  inline_label={Unit.abbreviation(unit(c))}
                  min="0.000001"
                  step="any"
                  required
                />
              </div>
            </:col>
          </.table>
        </section>
        <div class={[@batch_step != :result && "hidden"]}>
          <details
            id="batch-output-details"
            class="rounded-lg border border-stone-200 px-4 py-3"
          >
            <summary class="cursor-pointer text-sm font-medium text-stone-700">
              Lot details <span class="ml-1 font-normal text-stone-500">Code, expiry & notes</span>
            </summary>
            <div class="mt-4 space-y-4">
              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@batch_form[:lot_code]} type="text" required label="Output lot code" />
                <.input field={@batch_form[:expiry_date]} type="date" label="Expiry date (optional)" />
              </div>
              <.input
                field={@batch_form[:notes]}
                type="textarea"
                label="Batch notes (optional)"
                rows="2"
              />
            </div>
          </details>
        </div>
        <div
          id="batch-stock-preview"
          class={["rounded-lg bg-stone-50 px-4 py-3", @batch_step != :result && "hidden"]}
        >
          <p class="text-xs text-stone-500">Use {input_summary(@input_rows, @recipe)}</p>
          <p class="mt-2 text-sm font-semibold text-stone-900">
            Stock {@batch_form[:actual_quantity].value} {@material.unit} of {@material.name}
          </p>
          <p class="mt-1 text-xs text-stone-500">
            Input cost: {preview_cost(@input_rows, @lots, @materials, @settings.currency)} · {yield_percent(
              @batch_form[:actual_quantity].value,
              @batch_form[:planned_quantity].value
            )}% yield
          </p>
        </div>
        <p
          :if={@error}
          id="batch-error"
          role="alert"
          class="whitespace-pre-line rounded-lg bg-rose-50 p-3 text-sm text-rose-700"
        >
          {@error}
        </p>
        <div class="flex items-center justify-between gap-2 border-t border-stone-200 pt-4">
          <.button
            type="button"
            variant={:outline}
            phx-click={if @batch_step == :plan, do: "close_modal", else: "back_to_plan"}
          >{if @batch_step == :plan, do: "Cancel", else: "Back"}</.button>
          <.button
            :if={@batch_step == :plan}
            id="review-material-batch"
            type="submit"
            variant={:primary}
            phx-disable-with="Reviewing…"
          >Record result <.icon name="hero-arrow-right" class="h-4 w-4" /></.button>
          <.button
            :if={@batch_step == :result}
            id="complete-material-batch"
            type="submit"
            variant={:primary}
            phx-disable-with="Completing…"
          >Complete & stock</.button>
        </div>
      </.form>
    </.modal>
    """
  end
end
