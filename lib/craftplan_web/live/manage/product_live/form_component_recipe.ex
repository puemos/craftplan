defmodule CraftplanWeb.ProductLive.FormComponentRecipe do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Catalog
  alias Craftplan.Catalog.Services.BOMDuplicate
  alias Craftplan.Catalog.Services.BOMRecipeSync

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div>
      <div class="mb-4 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <label class="text-sm text-stone-600">Version</label>
          <%= if @settings.advanced_recipe_versioning do %>
            <select
              phx-change="switch_version"
              phx-target={@myself}
              name="bom_version"
              class="rounded border-stone-300 text-sm"
            >
              <option :if={(@boms || []) == []} value="">No BOMs</option>
              <%= for b <- @boms || [] do %>
                <option value={b.version} selected={@bom && @bom.version == b.version}>
                  v{b.version} · {b.status}{b.published_at && format_date(b.published_at)}
                </option>
              <% end %>
            </select>
          <% else %>
            <div class="text-sm text-stone-700">
              <%= if @bom && @bom.id do %>
                v{@bom.version} · {@bom.status}{@bom.published_at && format_date(@bom.published_at)}
              <% else %>
                No BOM yet
              <% end %>
            </div>
          <% end %>
        </div>
        <div class="flex items-center gap-2">
          <.button
            :if={@bom && @bom.status != :active}
            phx-click="promote"
            phx-target={@myself}
            size={:sm}
            variant={:outline}
          >
            Make Active
          </.button>
          <.button
            :if={@bom}
            phx-click="duplicate"
            phx-target={@myself}
            size={:sm}
            variant={:outline}
          >
            Duplicate
          </.button>
        </div>
      </div>
      <.simple_form
        for={@form}
        id="recipe-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:product_id]} type="hidden" value={@product.id} />

          <h3 class="text-lg font-medium">Recipe</h3>
          <p class="mb-2 text-sm text-stone-500">Add materials needed for this product</p>
          <div class="mb-4 flex items-center gap-2">
            <.button
              :if={(!@settings.advanced_recipe_versioning and @bom) && @bom.status == :active}
              phx-click="try_variation"
              phx-target={@myself}
              size={:sm}
              variant={:outline}
            >
              Try a variation
            </.button>
            <.button
              :if={(!@settings.advanced_recipe_versioning and @bom) && @bom.status == :draft}
              phx-click="promote"
              phx-target={@myself}
              size={:sm}
              variant={:primary}
            >
              Publish
            </.button>
            <.button
              :if={(!@settings.advanced_recipe_versioning and @bom) && @bom.status == :draft}
              phx-click="revert"
              phx-target={@myself}
              size={:sm}
              variant={:outline}
            >
              Revert
            </.button>
            <.link
              :if={!@settings.advanced_recipe_versioning}
              phx-click={JS.push("show_history", target: @myself)}
              class="text-sm text-blue-700 hover:underline"
            >
              Show version history
            </.link>
          </div>

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
                  Total Cost
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
                    </div>
                  </div>
                </div>
              </.inputs_for>

              <div role="row" class="col-span-4 py-4">
                <button
                  type="button"
                  phx-click="show_add_modal"
                  phx-target={@myself}
                  class={[
                    "inline-flex cursor-pointer items-center rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50",
                    Enum.empty?(@available_materials) && "cursor-not-allowed opacity-50"
                  ]}
                  disabled={Enum.empty?(@available_materials)}
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Material
                </button>
              </div>
            </div>
          </div>

          <.input
            class="field-sizing-content mt-6"
            field={@form[:notes]}
            type="textarea"
            label="Notes"
          />
        </div>

        <:actions>
          <.button
            variant={:primary}
            type="submit"
            disabled={
              ((@bom && @bom.status == :archived)) ||
                (((@bom && @bom.id) && (not @form.source.changed?))) ||
                (not @form.source.valid?)
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
          <div class="mt-4 space-y-6">
            <div class="max-h-64 overflow-y-auto">
              <ul class="divide-y divide-stone-200">
                <%= for material <- @available_materials do %>
                  <li>
                    <button
                      type="button"
                      phx-click="add_material"
                      phx-value-material-id={material.id}
                      phx-target={@myself}
                      class="w-full rounded-md px-3 py-2 text-left transition duration-150 ease-in-out hover:bg-stone-100"
                    >
                      {material.name}
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <.button phx-click="hide_modal" phx-target={@myself} class="mt-5">Cancel</.button>
        </.modal>
      <% end %>

      <div :if={@settings.advanced_recipe_versioning} class="mt-8">
        <h4 class="mb-2 text-sm font-semibold text-stone-700">Recipe History</h4>
        <.table id="bom-history" rows={@boms || []}>
          <:col :let={b} label="Version">v{b.version}</:col>
          <:col :let={b} label="Status">{b.status}</:col>
          <:col :let={b} label="Published">
            {if b.published_at, do: format_date(b.published_at), else: "-"}
          </:col>
          <:col :let={b} label="Unit Cost">
            {case b.rollup do
              %{} = r -> format_money(@settings.currency, r.unit_cost)
              _ -> "-"
            end}
          </:col>
          <:action :let={b}>
            <div class="flex gap-2">
              <.button
                size={:sm}
                variant={:outline}
                phx-target={@myself}
                phx-click="switch_version"
                phx-value-bom_version={b.version}
              >
                View
              </.button>
              <.button size={:sm} variant={:outline} phx-target={@myself} phx-click="duplicate">
                Duplicate
              </.button>
              <.button
                :if={b.status != :active}
                size={:sm}
                variant={:outline}
                phx-target={@myself}
                phx-click="promote_row"
                phx-value-bom_version={b.version}
              >
                Make Active
              </.button>
              <.button
                :if={b.status != :archived}
                size={:sm}
                variant={:danger}
                phx-target={@myself}
                phx-click="archive_row"
                phx-value-bom_version={b.version}
              >
                Archive
              </.button>
            </div>
          </:action>
        </.table>
      </div>
      <.modal
        :if={!@settings.advanced_recipe_versioning && @show_history}
        id="bom-history-modal"
        show
        title="Recipe History"
        on_cancel={JS.push("hide_history", target: @myself)}
      >
        <.table id="bom-history-modal-table" rows={@boms || []}>
          <:col :let={b} label="Version">v{b.version}</:col>
          <:col :let={b} label="Status">{b.status}</:col>
          <:col :let={b} label="Published">
            {if b.published_at, do: Calendar.strftime(b.published_at, "%Y-%m-%d"), else: "-"}
          </:col>
          <:col :let={b} label="Unit Cost">
            {case b.rollup do
              %{} = r -> r.unit_cost
              _ -> "-"
            end}
          </:col>
          <:action :let={b}>
            <div class="flex gap-2">
              <.button
                size={:sm}
                variant={:outline}
                phx-target={@myself}
                phx-click="switch_version"
                phx-value-bom_version={b.version}
              >
                View
              </.button>
              <.button size={:sm} variant={:outline} phx-target={@myself} phx-click="duplicate">
                Duplicate
              </.button>
              <.button
                :if={b.status != :active}
                size={:sm}
                variant={:outline}
                phx-target={@myself}
                phx-click="promote_row"
                phx-value-bom_version={b.version}
              >
                Make Active
              </.button>
              <.button
                :if={b.status != :archived}
                size={:sm}
                variant={:danger}
                phx-target={@myself}
                phx-click="archive_row"
                phx-value-bom_version={b.version}
              >
                Archive
              </.button>
            </div>
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
     |> assign(:show_modal, false)
     |> assign_new(:show_history, fn -> false end)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    form = Form.validate(socket.assigns.form, recipe_params)
    {:noreply, assign(socket, form: form, changed: true)}
  end

  @impl true
  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    if socket.assigns.settings.advanced_recipe_versioning do
      # advanced mode: keep existing version update behavior
      case Form.submit(socket.assigns.form, params: recipe_params) do
        {:ok, bom} ->
          send(self(), {__MODULE__, {:saved, bom}})

          {:noreply,
           socket
           |> assign(:bom, bom)
           |> put_flash(:info, "Recipe saved successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, form} ->
          {:noreply, assign(socket, :form, form)}
      end
    else
      # simple mode: saving creates a new version and makes it active
      actor = socket.assigns.current_user
      product = socket.assigns.product

      # Demote existing active to archived (if any)
      case Catalog.get_active_bom_for_product(%{product_id: product.id},
             actor: actor,
             authorize?: false
           ) do
        {:ok, %Catalog.BOM{} = active} ->
          _ = Ash.update(active, %{status: :archived}, action: :update, actor: actor, authorize?: false)

        _ ->
          :ok
      end

      components = build_components_from_params(recipe_params["components"] || %{})

      new_bom =
        Catalog.BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          status: :active,
          published_at: DateTime.utc_now(),
          components: components
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
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("switch_version", %{"bom_version" => v}, socket) do
    version =
      case Integer.parse(to_string(v)) do
        {n, _} -> n
        _ -> nil
      end

    socket = assign(socket, :selected_version, version)
    {:noreply, assign_form(socket)}
  end

  @impl true
  def handle_event("duplicate", _params, socket) do
    actor = socket.assigns.current_user
    bom = socket.assigns.bom

    _new =
      BOMDuplicate.duplicate!(bom, actor: actor, authorize?: false)

    socket = assign_lists(socket)
    {:noreply, socket |> assign_form() |> put_flash(:info, "BOM duplicated")}
  end

  @impl true
  def handle_event("promote", _params, socket) do
    actor = socket.assigns.current_user
    bom = socket.assigns.bom

    case Catalog.get_active_bom_for_product(%{product_id: socket.assigns.product.id},
           actor: actor,
           authorize?: false
         ) do
      {:ok, %Catalog.BOM{} = active} when active.id != bom.id ->
        _ = Ash.update(active, %{status: :archived}, action: :update, actor: actor, authorize?: false)

      _ ->
        :ok
    end

    _ = Ash.update(bom, %{}, action: :promote, actor: actor, authorize?: false)
    socket = assign_lists(socket)
    {:noreply, socket |> assign_form() |> put_flash(:info, "BOM is now active")}
  end

  @impl true
  def handle_event("revert", _params, socket) do
    actor = socket.assigns.current_user
    bom = socket.assigns.bom

    if bom && bom.id && bom.status == :draft do
      _ = Ash.destroy(bom, actor: actor, authorize?: false)
    end

    socket = assign_lists(socket)
    {:noreply, socket |> assign_form() |> put_flash(:info, "Changes reverted")}
  end

  @impl true
  def handle_event("try_variation", _params, socket) do
    actor = socket.assigns.current_user
    draft = Enum.find(socket.assigns.boms || [], fn b -> b.status == :draft end)

    socket =
      if draft do
        assign(socket, :selected_version, draft.version)
      else
        bom = socket.assigns.bom

        _new =
          BOMDuplicate.duplicate!(bom, actor: actor, authorize?: false)

        assign_lists(socket)
      end

    {:noreply, assign_form(socket)}
  end

  @impl true
  def handle_event("promote_row", %{"bom_version" => v}, socket) do
    actor = socket.assigns.current_user
    version = parse_int(v)
    bom = find_bom(socket.assigns.boms || [], version)

    if bom do
      case Catalog.get_active_bom_for_product(%{product_id: socket.assigns.product.id},
             actor: actor,
             authorize?: false
           ) do
        {:ok, %Catalog.BOM{} = active} when active.id != bom.id ->
          _ = Ash.update(active, %{status: :archived}, action: :update, actor: actor, authorize?: false)

        _ ->
          :ok
      end

      _ = Ash.update(bom, %{}, action: :promote, actor: actor, authorize?: false)
    end

    socket = assign_lists(socket)
    {:noreply, socket |> assign_form() |> put_flash(:info, "BOM is now active")}
  end

  @impl true
  def handle_event("archive_row", %{"bom_version" => v}, socket) do
    actor = socket.assigns.current_user
    version = parse_int(v)
    bom = find_bom(socket.assigns.boms || [], version)
    if bom, do: _ = Ash.update(bom, %{status: :archived}, actor: actor, authorize?: false)
    socket = assign_lists(socket)
    {:noreply, socket |> assign_form() |> put_flash(:info, "BOM archived")}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = Form.remove_form(socket.assigns.form, path)

    {available_materials, _selected_material} =
      recompute_availability(form, socket.assigns.materials)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:available_materials, available_materials)}
  end

  defp assign_form(socket) do
    actor = socket.assigns.current_user
    bom = select_bom(socket, actor)

    form =
      bom
      |> form_for_bom(actor)
      |> to_form()

    socket
    |> assign(:bom, bom)
    |> assign(:form, form)
  end

  defp assign_lists(socket) do
    actor = socket.assigns.current_user

    case Catalog.list_boms_for_product(%{product_id: socket.assigns.product.id},
           actor: actor,
           authorize?: false
         ) do
      {:ok, boms} ->
        boms = Ash.load!(boms, [:rollup], actor: actor, authorize?: false)
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
          Ash.load!(bom, [components: [:material, :product], labor_steps: []], actor: actor, authorize?: false)

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

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) do
    case Integer.parse(to_string(v)) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp find_bom(_boms, nil), do: nil
  defp find_bom(boms, ver), do: Enum.find(boms, fn b -> b.version == ver end)

  defp form_for_bom(bom, actor) do
    nested_forms = [
      components: [
        type: :list,
        data: bom.components || [],
        resource: Catalog.BOMComponent,
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
    |> Enum.sort_by(fn {k, _} -> k end)
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

  defp format_material_cost(currency, nil, _quantity) do
    format_money(currency, 0)
  end

  defp format_material_cost(currency, material, quantity) do
    price = material.price || Decimal.new(0)
    qty = normalize_decimal(quantity)

    format_money(currency, Decimal.mult(price, qty))
  end

  defp normalize_decimal(%Decimal{} = value), do: value
  defp normalize_decimal(nil), do: Decimal.new(0)
  defp normalize_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp normalize_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp normalize_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp normalize_decimal(_), do: Decimal.new(0)
end
