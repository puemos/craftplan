defmodule CraftplanWeb.SettingsLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Settings

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Settings" path={~p"/manage/settings"} current?={true} />
      </.breadcrumb>
    </.header>

    <.tabs id="settings-tabs">
      <:tab
        label="General"
        path={~p"/manage/settings/general"}
        selected?={@live_action == :general || @live_action == :index}
      >
        <div class="max-w-lg">
          <.live_component
            module={CraftplanWeb.SettingsLive.FormComponent}
            id="settings-form"
            current_user={@current_user}
            title={@page_title}
            action={@live_action}
            settings={@settings}
            patch={~p"/manage/settings/general"}
          />
        </div>
      </:tab>

      <:tab
        label="Allergens"
        path={~p"/manage/settings/allergens"}
        selected?={@live_action == :allergens}
      >
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.AllergensComponent}
            id="allergens-component"
            current_user={@current_user}
            allergens={@allergens}
          />
        </div>
      </:tab>

      <:tab
        label="Nutritional Facts"
        path={~p"/manage/settings/nutritional_facts"}
        selected?={@live_action == :nutritional_facts}
      >
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.NutritionalFactsComponent}
            id="nutritional-facts-component"
            current_user={@current_user}
            nutritional_facts={@nutritional_facts}
          />
        </div>
      </:tab>

      <:tab
        label="Import/Export"
        path={~p"/manage/settings/csv"}
        selected?={@live_action == :csv}
      >
        <div class="max-w-2xl">
          <h2 class="mb-2 text-lg font-medium">Import & Export</h2>
          <p class="mb-4 text-sm text-stone-700">Click on the entity you wish to import.</p>
          <div class="mb-8 flex gap-3">
            <.button phx-click="open_import" phx-value-entity="products">
              <.icon name="hero-cube-solid" class="h-4 w-4" />
              Products
            </.button>
            <.button variant={:outline} phx-click="open_import" phx-value-entity="materials">
              <.icon name="hero-archive-box-solid" class="h-4 w-4" />
              Materials
            </.button>
            <.button variant={:outline} phx-click="open_import" phx-value-entity="customers">
              <.icon name="hero-user-group-solid" class="h-4 w-4" />
              Customers
            </.button>
          </div>

          <h2 class="mt-10 mb-4 text-lg font-medium">Export</h2>
          <.form for={@csv_export_form} id="csv-export-form" phx-submit="csv_export">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                type="select"
                name="entity"
                label="Entity"
                options={[
                  {"Orders", "orders"},
                  {"Customers", "customers"},
                  {"Inventory Movements", "movements"}
                ]}
                value="orders"
                required
              />
            </div>
            <div class="mt-6 flex gap-2">
              <.button id="csv-export-submit">Export</.button>
            </div>
          </.form>
          <.modal :if={@show_mapping_modal} id="csv-mapping-modal" title={"Import " <> String.capitalize(@selected_entity || "")} show={true}>
            <div class="min-h-[520px]">
              <.stepper steps={["Provide CSV", "Mapping", "Verify", "Import"]} current={wizard_label(@wizard_step)} />
              <div class="mb-4 text-sm text-stone-700">
                <div class="font-medium">Here’s the format:</div>
                <div :if={@selected_entity == "products"}>Required: name, sku, price. Optional: status.</div>
                <div :if={@selected_entity == "materials"}>Required: name, sku, unit, price.</div>
                <div :if={@selected_entity == "customers"}>Required: type, first_name, last_name, email.</div>
                <div class="mt-2">
                  <.button variant={:outline} id="csv-template-download" type="button">Download template</.button>
                </div>
              </div>

              <.form :if={@wizard_step == :provide} for={@csv_form} id="csv-select-form" phx-submit="csv_import">
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <.input type="text" name="delimiter" label="Delimiter" value={@csv_delimiter || ","} />
                  <.input type="checkbox" name="dry_run" label="Dry run (preview)" checked />
                  <div class="sm:col-span-2">
                    <.input type="textarea" name="csv_content" label="Paste raw CSV" value="" />
                  </div>
                  <div class="sm:col-span-2">
                    <label class="mb-1 block text-sm font-medium text-stone-700">Or choose file…</label>
                    <.live_file_input upload={@uploads[:csv]} class="block w-full text-sm" />
                  </div>
                </div>
                <div class="mt-4 flex gap-2">
                  <.button id="csv-verify">Verify</.button>
                </div>
              </.form>

              <div class="mt-6" :if={@wizard_step in [:map, :verify, :import]}>
                <h4 class="mb-2 font-medium">Mapping</h4>
                <.form :if={@csv_headers != [] and @wizard_step in [:map, :verify, :import]} for={to_form(@csv_mapping)} id="csv-mapping-form" phx-submit="csv_validate">
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input type="select" name="mapping[name]" label="Name" options={@csv_headers} value={@csv_mapping["name"]} />
                    <.input type="select" name="mapping[sku]" label="SKU" options={@csv_headers} value={@csv_mapping["sku"]} />
                    <.input :if={@selected_entity == "products"} type="select" name="mapping[price]" label="Price" options={@csv_headers} value={@csv_mapping["price"]} />
                    <.input :if={@selected_entity == "products"} type="select" name="mapping[status]" label="Status" options={["" | @csv_headers]} value={@csv_mapping["status"]} />
                  </div>
                  <div class="mt-4 flex gap-2">
                    <.button id="csv-validate-submit">Validate</.button>
                    <.button :if={@wizard_step == :verify} variant={:outline} id="csv-import-final" type="button" phx-click="csv_import_final">Import</.button>
                    <.button :if={@wizard_step == :import} variant={:outline} disabled>Importing…</.button>
                  </div>
                </.form>

                <h4 class="mt-6 mb-2 font-medium">Preview</h4>
                <table class="min-w-full divide-y divide-stone-200 border">
                  <thead><tr>
                    <th :for={h <- @csv_headers} class="px-2 py-1 text-left text-xs font-medium text-stone-600">{h}</th>
                  </tr></thead>
                  <tbody class="divide-y divide-stone-100">
                    <tr :for={row <- @csv_rows}>
                      <td :for={i <- 0..(length(@csv_headers)-1)} class="px-2 py-1 text-xs">{Enum.at(row, i)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div :if={@csv_errors && @csv_errors != [] and @wizard_step in [:verify, :import]} class="mt-4">
                <h4 class="mb-2 font-medium">Errors</h4>
                <ul class="list-disc pl-6 text-sm text-red-700">
                  <li :for={e <- @csv_errors}>Row {e.row}: {e.message}</li>
                </ul>
              </div>
            </div>
          </.modal>
        </div>
      </:tab>
    </.tabs>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:allergens, allergens)
      |> assign(:nutritional_facts, nutritional_facts)
      |> assign(:csv_form, to_form(%{}))
      |> assign(:csv_export_form, to_form(%{}))
      |> assign(:csv_preview, nil)
      |> assign(:csv_headers, [])
      |> assign(:csv_rows, [])
      |> assign(:csv_mapping, %{})
      |> assign(:csv_errors, [])
      |> assign(:show_mapping_modal, false)
      |> assign(:csv_delimiter, ",")
      |> assign(:selected_entity, nil)
      |> assign(:wizard_step, :provide)
      |> assign_new(:current_user, fn -> nil end)

    # Always configure CSV upload; harmless on other tabs and avoids missing @uploads
    socket =
      allow_upload(socket, :csv,
        accept: [".csv", "text/csv"],
        max_entries: 1
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("open_import", %{"entity" => entity}, socket) do
    {:noreply,
     socket
     |> assign(:selected_entity, entity)
     |> assign(:csv_preview, nil)
     |> assign(:csv_headers, [])
     |> assign(:csv_rows, [])
     |> assign(:csv_mapping, %{})
     |> assign(:csv_errors, [])
     |> assign(:csv_delimiter, ",")
     |> assign(:wizard_step, :provide)
     |> assign(:show_mapping_modal, true)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Settings")
  end

  defp apply_action(socket, :general, _params) do
    assign(socket, :page_title, "General Settings")
  end

  defp apply_action(socket, :allergens, _params) do
    assign(socket, :page_title, "Allergens Settings")
  end

  defp apply_action(socket, :nutritional_facts, _params) do
    assign(socket, :page_title, "Nutritional Facts Settings")
  end

  defp apply_action(socket, :csv, _params) do
    assign(socket, :page_title, "CSV Import/Export")
  end

  @impl true
  def handle_event("csv_import", params, socket) do
    entity = params["entity"] || socket.assigns.selected_entity || "products"
    delimiter = params["delimiter"] || ","
    dry_run? = params["dry_run"] in [true, "true", "on", "1"]
    content = params["csv_content"] || ""

    cond do
      dry_run? and String.trim(content) != "" ->
        do_csv_preview(entity, content, delimiter, socket)

      dry_run? ->
        case consume_uploaded_csv(socket) do
          {:ok, csv_content} -> do_csv_preview(entity, csv_content, delimiter, socket)
          :error -> {:noreply, put_flash(socket, :info, "Upload a file or paste CSV content for dry run.")}
        end

      true ->
        {:noreply, put_flash(socket, :info, "Upload a file or paste CSV content for dry run.")}
    end
  end

  def handle_event("csv_export", _params, socket) do
    {:noreply, put_flash(socket, :info, "Export started (not yet implemented)")}
  end

  def handle_event("csv_preview", _params, socket), do: {:noreply, socket}

  def handle_event("csv_validate", %{"mapping" => mapping_params} = _params, socket) do
    entity = socket.assigns[:csv_entity] || "products"
    mapping = normalize_mapping_params(mapping_params)

    case socket.assigns[:csv_preview] do
      nil -> {:noreply, put_flash(socket, :error, "No CSV preview available")}
      csv -> do_csv_dry_run(entity, csv, socket.assigns[:csv_delimiter] || ",", mapping, socket)
    end
  end

  defp do_csv_preview(entity, csv, delimiter, socket) do
    headers =
      NimbleCSV.RFC4180.parse_string(csv, skip_headers: false, separator: delimiter)
      |> List.first()

    rows =
      csv
      |> String.trim()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: true, separator: delimiter)
      |> Enum.take(5)

    mapping = default_mapping_for(entity, headers)

    {:noreply,
     socket
     |> assign(:csv_preview, csv)
     |> assign(:csv_headers, headers || [])
     |> assign(:csv_rows, rows)
     |> assign(:csv_mapping, mapping)
     |> assign(:csv_entity, entity)
     |> assign(:csv_delimiter, delimiter)
     |> assign(:wizard_step, :map)
     |> assign(:show_mapping_modal, true)}
  end

  defp do_csv_dry_run("products", csv, delimiter, mapping, socket) do
    case Craftplan.CSV.Importers.Products.dry_run(csv, delimiter: delimiter, mapping: mapping) do
      {:ok, %{rows: rows, errors: errors}} ->
        msg = "Dry run: #{length(rows)} rows valid, #{length(errors)} errors"
        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> assign(:csv_errors, errors)
         |> assign(:wizard_step, :verify)}
    end
  end

  defp do_csv_dry_run(_, _csv, _delim, _mapping, socket) do
    {:noreply, put_flash(socket, :error, "Only products dry-run supported yet")}
  end

  @impl true
  def handle_event("csv_import_final", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Import not implemented yet")
     |> assign(:wizard_step, :import)}
  end

  defp wizard_label(step) do
    case step do
      :provide -> "Provide CSV"
      :map -> "Mapping"
      :verify -> "Verify"
      :import -> "Import"
      _ -> "Provide CSV"
    end
  end

  defp consume_uploaded_csv(socket) do
    entries = socket.assigns.uploads[:csv] && socket.assigns.uploads.csv.entries || []
    if entries == [] do
      :error
    else
      {content, _} =
        consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
          {:ok, File.read!(path)}
        end)
      {:ok, content}
    end
  end

  defp default_mapping_for("products", headers) do
    norm = Enum.map(headers || [], &String.downcase(to_string(&1)))
    %{
      "name" => find_header(norm, ["name", "product name"]),
      "sku" => find_header(norm, ["sku", "code"]),
      "price" => find_header(norm, ["price", "cost", "amount"]),
      "status" => find_header(norm, ["status"]) || ""
    }
  end

  defp default_mapping_for(_, _headers), do: %{}

  defp find_header(norm_headers, candidates) do
    Enum.find(norm_headers, fn h -> h in candidates end)
  end

  defp normalize_mapping_params(params) do
    params
    |> Enum.into(%{}, fn {k, v} -> {k, String.downcase(to_string(v || ""))} end)
  end

  @impl true
  def handle_info({CraftplanWeb.SettingsLive.FormComponent, {:saved, settings}}, socket) do
    {:noreply, assign(socket, :settings, settings)}
  end

  @impl true
  def handle_info({:saved_allergens, _id}, socket) do
    allergens = Inventory.list_allergens!()
    {:noreply, assign(socket, :allergens, allergens)}
  end

  @impl true
  def handle_info({:saved_nutritional_facts, _id}, socket) do
    nutritional_facts = Inventory.list_nutritional_facts!()
    {:noreply, assign(socket, :nutritional_facts, nutritional_facts)}
  end
end
