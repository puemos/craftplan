defmodule CraftplanWeb.ProductLive.FormComponentRecipe do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Catalog
  alias Craftplan.Catalog.Services.BOMRecipeSync
  alias Decimal, as: D

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div>
      <div class="mb-4 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div :if={@bom.version != nil} class="flex items-center gap-2 text-sm text-stone-700">
            <span>Version <span>v{@bom.version}</span></span>

            <%= if latest_version(@boms) == @bom.version do %>
              <span class="text-[11px] rounded bg-green-100 px-1 py-0.5 font-medium text-green-700">
                Latest
              </span>
            <% end %>
            <span> · </span>
            <span>Changed on</span>
            <span class="underline decoration-stone-400 decoration-dashed">
              {@bom.published_at && format_date(@bom.published_at)}
            </span>
          </div>
        </div>
        <div :if={@bom.version != nil} class="flex items-center gap-2">
          <.link
            phx-click={JS.push("show_history", target: @myself)}
            class="text-sm text-blue-700 hover:underline"
          >
            <.button size={:sm} variant={:outline}>Show version history</.button>
          </.link>
        </div>
      </div>
      <%= if Enum.any?(@boms || []) and @bom && @bom.id && latest_version(@boms) != @bom.version do %>
        <div class="mb-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          You are viewing an older version (v{@bom.version}). Latest is v{latest_version(@boms)}.
          <.button
            class="ml-2"
            size={:sm}
            variant={:outline}
            phx-click="switch_version"
            phx-target={@myself}
            phx-value-bom_version={latest_version(@boms)}
          >
            Go to latest
          </.button>
        </div>
      <% end %>

      <.simple_form
        for={@form}
        id="recipe-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="">
          <.input field={@form[:product_id]} type="hidden" value={@product.id} />

          <h3 class="text-lg font-medium">Materials</h3>
          <p class="mb-2 text-sm text-stone-500">
            Add materials needed for this product
          </p>

          <div id="recipe-materials-list">
            <div
              id="recipe"
              class="mt-2 grid w-full grid-cols-4 gap-x-4 text-sm leading-6 text-stone-700"
            >
              <div
                role="row"
                class="col-span-4 grid grid-cols-4 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
              >
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0 ">
                  Material
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  Quantity
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  <span>Total Cost</span>
                  <span class="text-stone-700">
                    ({format_money(@settings.currency, @materials_total || D.new(0))})
                  </span>
                </div>
                <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                  <span class="opacity-0">Actions</span>
                </div>
              </div>

              <div role="row" class="col-span-4 hidden py-4 text-stone-400 last:block">
                <div>
                  No materials in recipe
                </div>
              </div>

              <.inputs_for :let={components_form} field={@form[:components]}>
                <div role="row" class="group col-span-4 grid grid-cols-4 hover:bg-stone-200/40">
                  <% material = material_for_form(@materials_map, components_form) %>
                  <div class="relative border-r border-b border-stone-200 p-0 last:border-r-0 ">
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        <.link
                          :if={material}
                          navigate={~p"/manage/inventory/#{material.sku}"}
                          class="hover:text-blue-800 hover:underline"
                        >
                          {material.name}
                        </.link>
                        <span :if={!material} class="text-stone-400">
                          Select material
                        </span>
                        <.input
                          field={components_form[:material_id]}
                          value={components_form[:material_id].value}
                          type="hidden"
                        />
                        <.input
                          field={components_form[:component_type]}
                          value={components_form[:component_type].value || :material}
                          type="hidden"
                        />
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative -mt-2">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={components_form[:quantity]}
                            type="number"
                            min="0"
                            step="0.01"
                            inline_label={get_material_unit(@materials_map, components_form)}
                            disabled={latest_version(@boms) != @bom.version}
                          />
                        </div>
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <span class="relative">
                        {format_material_cost(
                          @settings.currency,
                          material,
                          components_form[:quantity].value
                        )}
                      </span>
                    </div>
                  </div>

                  <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                    <div class="block py-4 pr-6">
                      <%= if latest_version(@boms) != @bom.version do %>
                        <span class="text-stone-400">Read-only</span>
                      <% else %>
                        <label class="cursor-pointer">
                          <input
                            type="checkbox"
                            phx-click="remove_form"
                            phx-target={@myself}
                            phx-value-path={components_form.name}
                            class="hidden"
                          />
                          <span class="font-semibold leading-6 text-stone-900 hover:text-stone-700">
                            Remove
                          </span>
                        </label>
                      <% end %>
                    </div>
                  </div>
                </div>
              </.inputs_for>

              <div role="row" class="mt-3">
                <button
                  type="button"
                  phx-click="show_add_modal"
                  phx-target={@myself}
                  class={[
                    "inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50",
                    (Enum.empty?(@available_materials) || latest_version(@boms) != @bom.version) &&
                      "cursor-not-allowed opacity-50"
                  ]}
                  disabled={
                    Enum.empty?(@available_materials) || latest_version(@boms) != @bom.version
                  }
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Material
                </button>
              </div>
            </div>
          </div>

          <div class="mt-8">
            <h3 class="text-lg font-medium">Labor steps</h3>
            <p class="mb-2 text-sm text-stone-500">
              Track each step that consumes paid time. Override the hourly rate per step to fine-tune costs.
            </p>
            <div class="mt-4 rounded-md border border-stone-200 bg-stone-50 px-4 py-3 text-sm text-stone-600">
              <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p>
                    Hourly rate: {format_money(@settings.currency, @settings.labor_hourly_rate)} · Overhead: {format_percentage(
                      @settings.labor_overhead_percent
                    )}%
                  </p>
                </div>
                <.link
                  navigate={~p"/manage/settings/general"}
                  class="text-sm font-medium text-blue-700 hover:underline"
                >
                  Update in settings
                </.link>
              </div>
            </div>

            <div id="recipe-labor-list">
              <div
                id="labor"
                class="mt-2 grid w-full grid-cols-5 gap-x-4 text-sm leading-6 text-stone-700"
              >
                <div
                  role="row"
                  class="col-span-5 grid grid-cols-5 border-b border-stone-300 text-left text-sm leading-6 text-stone-500"
                >
                  <div class="border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0">
                    Step
                  </div>
                  <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                    Minutes
                  </div>
                  <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                    Units per run
                  </div>
                  <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                    Hourly rate override
                  </div>
                  <div class="border-r border-stone-200 p-0 pr-6 pb-4 pl-4 font-normal last:border-r-0">
                    <span class="opacity-0">Actions</span>
                  </div>
                </div>

                <div role="row" class="col-span-5 hidden py-4 text-stone-400 last:block">
                  <div>No labor steps yet</div>
                </div>

                <.inputs_for :let={labor_form} field={@form[:labor_steps]}>
                  <div role="row" class="col-span-5 grid grid-cols-5">
                    <div class="relative border-r border-b border-stone-200 p-0 pr-6 last:border-r-0">
                      <div class="block py-4">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={labor_form[:name]}
                            type="text"
                            placeholder="e.g. Mix dough"
                            disabled={latest_version(@boms) != @bom.version}
                          />
                        </div>
                        <.input
                          field={labor_form[:sequence]}
                          type="hidden"
                          value={labor_form[:sequence].value}
                        />
                      </div>
                    </div>

                    <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                      <div class="block py-4 pr-6">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={labor_form[:duration_minutes]}
                            type="number"
                            min="0"
                            step="1"
                            inline_label="min"
                            disabled={latest_version(@boms) != @bom.version}
                          />
                        </div>
                      </div>
                    </div>

                    <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                      <div class="block py-4 pr-6">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={labor_form[:units_per_run]}
                            type="number"
                            min="1"
                            step="0.01"
                            placeholder="Default 1"
                            disabled={latest_version(@boms) != @bom.version}
                          />
                        </div>
                      </div>
                    </div>

                    <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                      <div class="block py-4 pr-6">
                        <div class="border-b border-dashed border-stone-300">
                          <.input
                            flat={true}
                            field={labor_form[:rate_override]}
                            type="number"
                            min="0"
                            step="0.01"
                            placeholder="Uses default when blank"
                            disabled={latest_version(@boms) != @bom.version}
                          />
                        </div>
                      </div>
                    </div>

                    <div class="relative border-r border-b border-stone-200 p-0 pl-4 last:border-r-0">
                      <div class="block py-4 pr-6">
                        <%= if latest_version(@boms) != @bom.version do %>
                          <span class="text-stone-400">Read-only</span>
                        <% else %>
                          <label class="cursor-pointer">
                            <input
                              type="checkbox"
                              phx-click="remove_form"
                              phx-target={@myself}
                              phx-value-path={labor_form.name}
                              class="hidden"
                            />
                            <span class="font-semibold leading-6 text-stone-900 hover:text-stone-700">
                              Remove
                            </span>
                          </label>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </.inputs_for>

                <div role="row" class="col-span-5 py-4">
                  <button
                    type="button"
                    phx-click="add_labor_step"
                    phx-target={@myself}
                    class={[
                      "inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50",
                      latest_version(@boms) != @bom.version && "cursor-not-allowed opacity-50"
                    ]}
                    disabled={latest_version(@boms) != @bom.version}
                  >
                    <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add labor step
                  </button>
                </div>
              </div>
            </div>
          </div>

          <.input
            class="field-sizing-content mt-6"
            field={@form[:notes]}
            type="textarea"
            label="Notes"
            disabled={latest_version(@boms) != @bom.version}
          />
        </div>

        <:actions>
          <.button
            :if={latest_version(@boms) == @bom.version}
            variant={:primary}
            type="submit"
            disabled={
              (@bom && @bom.status == :archived) ||
                (@bom && @bom.id && not @form.source.changed?) ||
                not @form.source.valid?
            }
            phx-disable-with="Saving..."
          >
            Save Recipe
          </.button>
        </:actions>
      </.simple_form>

      <%= if @show_modal do %>
        <.modal
          title="Select a material to add to the recipe:"
          id="add-recipe-material-modal"
          show
          on_cancel={JS.push("hide_modal", target: @myself)}
        >
          <div class="space-y-4 p-4 sm:p-6">
            <form
              id="material-filter"
              phx-change="filter_materials"
              phx-target={@myself}
              class="flex items-center gap-2"
            >
              <input
                type="search"
                name="query"
                value={@material_query}
                placeholder="Search by name or SKU..."
                phx-debounce="300"
                class="w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 transition focus:border-primary-400 focus:outline-none focus:ring focus:ring-primary-200/60"
              />
            </form>

            <div class="h-[28rem] overflow-y-auto">
              <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                <%= for material <- @visible_materials do %>
                  <button
                    type="button"
                    phx-click="add_material"
                    phx-value-material-id={material.id}
                    phx-target={@myself}
                    class="group w-full rounded-md border border-stone-200 bg-white p-3 text-left shadow-sm transition hover:border-stone-300 hover:bg-stone-50 focus:outline-none focus:ring-2 focus:ring-blue-400"
                  >
                    <div class="flex items-start justify-between">
                      <span class="line-clamp-2 font-medium text-stone-900">{material.name}</span>
                      <span class="ml-2 inline-flex items-center rounded bg-stone-100 px-1.5 py-0.5 text-xs text-stone-600">
                        {material.unit}
                      </span>
                    </div>
                    <div class="mt-1 text-xs text-stone-500">
                      <span class="font-mono">{material.sku}</span>
                    </div>
                    <div class="mt-2 text-sm text-stone-700">
                      Price: {format_money(@settings.currency, material.price || D.new(0))}
                    </div>
                  </button>
                <% end %>
              </div>
              <div :if={Enum.empty?(@visible_materials)} class="py-8 text-center text-sm text-stone-500">
                No materials match your search.
              </div>
            </div>

            <div class="flex justify-end">
              <.button phx-click="hide_modal" phx-target={@myself} variant={:outline}>Close</.button>
            </div>
          </div>
        </.modal>
      <% end %>

      <.modal
        :if={@show_history}
        id="bom-history-modal"
        show
        title="Recipe History"
        max_width="max-w-4xl"
        on_cancel={JS.push("hide_history", target: @myself)}
      >
        <.table id="bom-history-modal-table" rows={@boms || []}>
          <:col :let={b} label="Version">v{b.version}</:col>
          <:col :let={b} label="Status">{b.status}</:col>
          <:col :let={b} label="Published">
            {if b.published_at, do: format_date(b.published_at, format: :short), else: "-"}
          </:col>
          <:col :let={b} label="Unit Cost">
            {case b.rollup do
              %{} = r -> format_money(@settings.currency, r.unit_cost || Decimal.new(0))
              _ -> "-"
            end}
          </:col>
          <:action :let={b}>
            <.button
              size={:sm}
              variant={:outline}
              phx-target={@myself}
              phx-click="switch_version"
              phx-value-bom_version={b.version}
            >
              View
            </.button>
          </:action>
        </.table>
        <div class="mt-4 flex justify-end">
          <.button variant={:outline} phx-click="hide_history" phx-target={@myself}>Close</.button>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket = assign_lists(socket)
    socket = assign_form(socket)

    materials_map =
      Map.new(assigns.materials, fn m -> {m.id, m} end)

    {available_materials, _selected_material} =
      recompute_availability(socket.assigns.form, assigns.materials)

    {:ok,
     socket
     |> assign(:changed, false)
     |> assign(:materials_map, materials_map)
     |> assign(:available_materials, available_materials)
     |> assign_new(:material_query, fn -> "" end)
     |> assign(:visible_materials, filter_available_materials(available_materials, socket.assigns[:material_query] || ""))
     |> assign(:show_modal, false)
     |> compute_recipe_totals()
     |> assign_new(:show_history, fn -> false end)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    form = Form.validate(socket.assigns.form, recipe_params)
    {:noreply, socket |> assign(form: form, changed: true) |> compute_recipe_totals()}
  end

  @impl true
  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    # simple mode: saving creates a new version and makes it active
    actor = socket.assigns.current_user
    product = socket.assigns.product

    # Demote existing active to archived (if any)
    case Catalog.get_active_bom_for_product(%{product_id: product.id},
           actor: actor,
           authorize?: false
         ) do
      {:ok, %Catalog.BOM{} = active} ->
        _ =
          Ash.update(active, %{status: :archived},
            action: :update,
            actor: actor,
            authorize?: false
          )

      _ ->
        :ok
    end

    components = build_components_from_params(recipe_params["components"] || %{})
    labor_steps = build_labor_steps_from_params(recipe_params["labor_steps"] || %{})
    notes = blank_to_nil(recipe_params["notes"])

    new_bom =
      Catalog.BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        status: :active,
        published_at: DateTime.utc_now(),
        notes: notes,
        components: components,
        labor_steps: labor_steps
      })
      |> Ash.create!(actor: actor, authorize?: false)

    socket = assign_lists(socket)

    {:noreply,
     socket
     |> assign(:selected_version, new_bom.version)
     |> assign_form()
     |> put_flash(:info, "Recipe saved successfully")
     |> push_patch(to: socket.assigns.patch)}
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    # Only show the modal if there are materials to add
    if Enum.empty?(socket.assigns.available_materials) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_modal, true)}
    end
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("show_history", _, socket) do
    {:noreply, assign(socket, :show_history, true)}
  end

  @impl true
  def handle_event("hide_history", _, socket) do
    {:noreply, assign(socket, :show_history, false)}
  end

  @impl true
  def handle_event("add_material", %{"material-id" => material_id}, socket) do
    # Add a new component form with the selected material
    form =
      Form.add_form(socket.assigns.form, socket.assigns.form[:components].name,
        params: %{material_id: material_id, quantity: 0, component_type: :material}
      )

    # Recompute available materials after adding this one
    {available_materials, _selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)
     |> assign(:visible_materials, filter_available_materials(available_materials, socket.assigns[:material_query] || ""))
     |> assign(:show_modal, false)
     |> compute_recipe_totals()}
  end

  @impl true
  def handle_event("add_labor_step", _params, socket) do
    if latest_version(socket.assigns.boms) == socket.assigns.bom.version do
      form =
        Form.add_form(socket.assigns.form, socket.assigns.form[:labor_steps].name,
          params: %{name: "", duration_minutes: 0, units_per_run: 1, rate_override: nil}
        )

      {:noreply, socket |> assign(:form, form) |> compute_recipe_totals()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_version", %{"bom_version" => v}, socket) do
    version =
      case Integer.parse(to_string(v)) do
        {n, _} -> n
        _ -> nil
      end

    to =
      case version do
        nil -> socket.assigns.patch
        n -> socket.assigns.patch <> "?v=" <> Integer.to_string(n)
      end

    {:noreply, socket |> assign(:show_history, false) |> push_patch(to: to)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = Form.remove_form(socket.assigns.form, path)

    {available_materials, _selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)
     |> assign(:visible_materials, filter_available_materials(available_materials, socket.assigns[:material_query] || ""))
     |> compute_recipe_totals()}
  end

  @impl true
  def handle_event("filter_materials", %{"query" => query}, socket) do
    q = to_string(query || "")

    {:noreply,
     socket
     |> assign(:material_query, q)
     |> assign(:visible_materials, filter_available_materials(socket.assigns.available_materials, q))}
  end

  defp assign_form(socket) do
    actor = socket.assigns.current_user
    bom = select_bom(socket, actor)

    bom =
      if bom && bom.id do
        Ash.load!(bom, [:rollup, labor_steps: []], actor: actor, authorize?: false)
      else
        bom
      end

    form =
      bom
      |> form_for_bom(actor)
      |> to_form()

    socket
    |> assign(:bom, bom)
    |> assign(:form, form)
  end

  defp compute_recipe_totals(socket) do
    actor_settings = socket.assigns.settings

    comps = socket.assigns.form.source.forms[:components] || []

    materials_total =
      Enum.reduce(comps, D.new(0), fn comp_form, acc ->
        material_id =
          comp_form.params[:material_id] ||
            (comp_form.data &&
               (comp_form.data.material_id ||
                  (comp_form.data.material && comp_form.data.material.id)))

        material = Map.get(socket.assigns.materials_map, material_id)
        qty = comp_form.params[:quantity] || (comp_form.data && comp_form.data.quantity) || 0
        price = (material && (material.price || D.new(0))) || D.new(0)
        D.add(acc, D.mult(price, normalize_decimal(qty)))
      end)

    steps = socket.assigns.form.source.forms[:labor_steps] || []

    {total_min, per_unit_min, per_unit_cost} =
      Enum.reduce(steps, {D.new(0), D.new(0), D.new(0)}, fn step_form, {tm, pum, puc} ->
        minutes =
          normalize_decimal(
            step_form.params[:duration_minutes] ||
              (step_form.data && step_form.data.duration_minutes) || 0
          )

        upr =
          normalize_units_per_run(step_form.params[:units_per_run] || (step_form.data && step_form.data.units_per_run))

        rate_override =
          normalize_optional_decimal(step_form.params[:rate_override] || (step_form.data && step_form.data.rate_override))

        rate = rate_override || actor_settings.labor_hourly_rate || D.new(0)
        per_unit_min_step = D.div(minutes, upr)
        per_unit_cost_step = per_unit_min_step |> D.div(D.new(60)) |> D.mult(rate)
        {D.add(tm, minutes), D.add(pum, per_unit_min_step), D.add(puc, per_unit_cost_step)}
      end)

    socket
    |> assign(:materials_total, materials_total)
    |> assign(:labor_total_minutes, total_min)
    |> assign(:labor_per_unit_minutes, per_unit_min)
    |> assign(:labor_per_unit_cost, per_unit_cost)
  end

  defp assign_lists(socket) do
    actor = socket.assigns.current_user

    case Catalog.list_boms_for_product(%{product_id: socket.assigns.product.id},
           actor: actor,
           authorize?: false
         ) do
      {:ok, boms} ->
        boms = Ash.load!(boms, [:rollup, labor_steps: []], actor: actor, authorize?: false)
        assign(socket, :boms, boms)

      _ ->
        assign(socket, :boms, [])
    end
  end

  defp select_bom(socket, actor) do
    selected =
      Map.get(socket.assigns, :selected_version) ||
        Map.get(socket.assigns, :selected_version, nil)

    if is_integer(selected) do
      case Catalog.list_boms_for_product(%{product_id: socket.assigns.product.id},
             actor: actor,
             authorize?: false
           ) do
        {:ok, [first | _] = boms} ->
          bom = Enum.find(boms, first, fn b -> b.version == selected end)

          Ash.load!(bom, [components: [:material, :product], labor_steps: []],
            actor: actor,
            authorize?: false
          )

        _ ->
          BOMRecipeSync.load_bom_for_product(socket.assigns.product,
            actor: actor,
            authorize?: false
          )
      end
    else
      BOMRecipeSync.load_bom_for_product(socket.assigns.product,
        actor: actor,
        authorize?: false
      )
    end
  end

  defp form_for_bom(bom, actor) do
    nested_forms = [
      components: [
        type: :list,
        data: bom.components || [],
        resource: Catalog.BOMComponent,
        create_action: :create,
        update_action: :update
      ],
      labor_steps: [
        type: :list,
        data: bom.labor_steps || [],
        resource: Catalog.LaborStep,
        create_action: :create,
        update_action: :update
      ]
    ]

    base_opts = [
      as: "recipe",
      actor: actor,
      forms: nested_forms
    ]

    if bom.id do
      Form.for_update(bom, :update, base_opts)
    else
      Form.for_create(
        Catalog.BOM,
        :create,
        Keyword.put(base_opts, :params, %{"product_id" => bom.product_id})
      )
    end
  end

  defp build_components_from_params(components_map) when is_map(components_map) do
    components_map
    |> Enum.sort_by(fn {k, _} -> to_integer(k) end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{_k, comp}, idx} ->
      %{
        component_type: :material,
        material_id: comp["material_id"] || comp[:material_id],
        quantity: normalize_decimal(comp["quantity"] || comp[:quantity] || 0),
        position: idx
      }
    end)
  end

  defp build_labor_steps_from_params(labor_map) when is_map(labor_map) do
    labor_map
    |> Enum.sort_by(fn {k, _} -> to_integer(k) end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{_key, step}, sequence} ->
      %{
        name: blank_to_nil(step["name"] || step[:name]),
        duration_minutes: normalize_decimal(step["duration_minutes"] || step[:duration_minutes] || 0),
        units_per_run: normalize_units_per_run(step["units_per_run"] || step[:units_per_run]),
        rate_override: normalize_optional_decimal(step["rate_override"] || step[:rate_override]),
        sequence: sequence
      }
    end)
    |> Enum.reject(&is_nil(&1.name))
  end

  defp build_labor_steps_from_params(_), do: []

  defp get_material_unit(materials_map, components_form) do
    case material_for_form(materials_map, components_form) do
      nil -> ""
      material -> material.unit
    end
  end

  defp recompute_availability(form, all_materials) do
    existing_material_ids =
      (form.source.forms[:components] || [])
      |> Enum.map(fn recipe_mat_form ->
        if material_component?(recipe_mat_form) do
          recipe_mat_form.params[:material_id] ||
            (recipe_mat_form.data && recipe_mat_form.data.material_id)
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    available_materials =
      Enum.reject(all_materials, fn m -> m.id in existing_material_ids end)

    selected_material =
      case available_materials do
        [first | _] -> first.id
        [] -> nil
      end

    {available_materials, selected_material}
  end

  defp filter_available_materials(materials, query) when is_binary(query) do
    q = String.trim(String.downcase(query))

    if q == "" do
      materials
    else
      Enum.filter(materials, fn m ->
        name = String.downcase(m.name || "")
        sku = String.downcase(m.sku || "")
        String.contains?(name, q) or String.contains?(sku, q)
      end)
    end
  end

  defp material_component?(component_form) do
    type =
      component_form.params[:component_type] ||
        (component_form.data && component_form.data.component_type) ||
        :material

    case type do
      type when is_binary(type) -> String.to_existing_atom(type)
      type -> type
    end == :material
  rescue
    ArgumentError -> false
  end

  defp material_for_form(materials_map, components_form) do
    material_id =
      components_form[:material_id].value ||
        (components_form.data &&
           (components_form.data.material_id ||
              (components_form.data.material && components_form.data.material.id)))

    Map.get(materials_map, material_id)
  end

  defp latest_version([]), do: nil
  defp latest_version(nil), do: nil

  defp latest_version(boms) do
    boms
    |> Enum.map(& &1.version)
    |> Enum.max()
  end

  defp format_material_cost(currency, nil, _quantity) do
    format_money(currency, 0)
  end

  defp format_material_cost(currency, material, quantity) do
    price = material.price || D.new(0)
    qty = normalize_decimal(quantity)

    format_money(currency, D.mult(price, qty))
  end

  defp normalize_optional_decimal(nil), do: nil
  defp normalize_optional_decimal(""), do: nil
  defp normalize_optional_decimal(value), do: normalize_decimal(value)

  defp normalize_units_per_run(nil), do: D.new(1)
  defp normalize_units_per_run(""), do: D.new(1)

  defp normalize_units_per_run(value) do
    decimal = normalize_decimal(value)

    if D.compare(decimal, D.new(0)) == :gt do
      decimal
    else
      D.new(1)
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_integer(_), do: 0

  defp normalize_decimal(%D{} = value), do: value
  defp normalize_decimal(nil), do: D.new(0)
  defp normalize_decimal(value) when is_binary(value), do: D.new(value)
  defp normalize_decimal(value) when is_integer(value), do: D.new(value)
  defp normalize_decimal(value) when is_float(value), do: D.from_float(value)
  defp normalize_decimal(_), do: D.new(0)
end
