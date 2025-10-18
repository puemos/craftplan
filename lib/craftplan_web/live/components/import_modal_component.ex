defmodule CraftplanWeb.ImportModalComponent do
  @moduledoc """
  Reusable CSV Import modal as a self-contained LiveComponent.

  Features:
  - Sticky stepper with backward navigation by clicking earlier steps
  - Provide CSV (paste or upload), Mapping, Import wizard
  - Mapping/Preview/Errors tabbed view to reduce scrolling
  - Footer actions rendered via the underlying modal component
  - Emits {:import_modal, :closed} message to the parent on close
  """
  use CraftplanWeb, :live_component

  # Internal assigns defaults
  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:csv_form, fn -> to_form(%{}) end)
      |> assign_new(:csv_export_form, fn -> to_form(%{}) end)
      |> assign_new(:csv_preview, fn -> nil end)
      |> assign_new(:csv_headers, fn -> [] end)
      |> assign_new(:csv_rows, fn -> [] end)
      |> assign_new(:csv_mapping, fn -> %{} end)
      |> assign_new(:csv_errors, fn -> [] end)
      |> assign_new(:csv_delimiter, fn -> "," end)
      |> assign_new(:dry_run_summary, fn -> nil end)
      |> assign_new(:wizard_step, fn -> :provide end)
      |> assign_new(:map_view_tab, fn -> :mapping end)

    # Configure upload once per parent view.
    socket =
      if socket.assigns[:_upload_init] do
        socket
      else
        socket
        |> allow_upload(:csv, accept: [".csv", "text/csv"], max_entries: 1)
        |> assign(:_upload_init, true)
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :config, entity_config(assigns[:entity]))

    ~H"""
    <div id={@id <> "-wrap"}>
      <.modal :if={@show} id={@id} title={"Import " <> String.capitalize(@entity || "")} show={true}>
        <div class="h-[600px] overflow-auto">
          <div
            phx-target={@myself}
            class="bg-white/95 sticky top-0 z-20 -mx-6 mb-4 px-6 py-3 backdrop-blur supports-[backdrop-filter]:bg-white/60"
          >
            <.stepper
              steps={["Provide CSV", "Mapping", "Import"]}
              current={wizard_label(@wizard_step)}
              goto_event="wizard_goto"
            />
          </div>

          <div class="mb-4 text-sm text-stone-700">
            <div class="font-medium">Here’s the format:</div>
            <div :for={line <- @config.instructions}>{line}</div>
            <div class="mt-2">
              <.button variant={:outline} id="csv-template-download" type="button">
                Download template
              </.button>
            </div>
          </div>

          <.form
            :if={@wizard_step == :provide}
            for={@csv_form}
            id="csv-select-form"
            phx-target={@myself}
            phx-submit="csv_import"
          >
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
          </.form>

          <div :if={@wizard_step in [:map, :import]} class="mt-6">
            <div class="mb-2 flex items-center justify-between">
              <h4 class="font-medium">Data</h4>
              <div :if={@csv_errors && @csv_errors != []} class="text-xs text-red-700">
                {length(@csv_errors)} error(s)
              </div>
            </div>
            <div class="mb-2">
              <div
                role="tablist"
                aria-orientation="horizontal"
                class="bg-stone-200/50 inline-flex h-9 rounded-lg p-1"
              >
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="mapping"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :mapping && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :mapping && "border-transparent"
                  ]}
                >
                  Mapping
                </button>
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="preview"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :preview && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :preview && "border-transparent"
                  ]}
                >
                  Preview
                </button>
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="errors"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :errors && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :errors && "border-transparent"
                  ]}
                >
                  Errors
                </button>
              </div>
            </div>
            <div class="rounded-md border bg-white">
              <div
                :if={@dry_run_summary && @map_view_tab in [:preview, :errors]}
                class="border-b px-3 py-2 text-xs text-stone-700"
              >
                {@dry_run_summary}
              </div>
              <div class="max-h-96 overflow-auto p-2">
                <div :if={@map_view_tab == :mapping}>
                  <.form
                    :if={@csv_headers != [] and @wizard_step in [:map, :import]}
                    for={to_form(@csv_mapping)}
                    id="csv-mapping-form"
                    phx-target={@myself}
                    phx-submit="csv_validate"
                  >
                    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                      <%= for f <- @config.fields do %>
                        <.input
                          type="select"
                          name={"mapping[#{f.name}]"}
                          label={f.label}
                          options={if f.required, do: @csv_headers, else: ["" | @csv_headers]}
                          value={@csv_mapping[f.name]}
                        />
                      <% end %>
                    </div>
                  </.form>
                </div>
                <div :if={@map_view_tab == :preview}>
                  <table class="min-w-full divide-y divide-stone-200 border">
                    <thead>
                      <tr>
                        <th
                          :for={h <- @csv_headers}
                          class="px-2 py-1 text-left text-xs font-medium text-stone-600"
                        >
                          {h}
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-stone-100">
                      <tr :for={row <- @csv_rows}>
                        <td :for={i <- 0..(length(@csv_headers) - 1)} class="px-2 py-1 text-xs">
                          {Enum.at(row, i)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div :if={@map_view_tab == :errors}>
                  <div :if={@csv_errors == []} class="text-sm text-stone-600">No errors.</div>
                  <div :if={@csv_errors && @csv_errors != []}>
                    <table class="min-w-full divide-y divide-red-200 border">
                      <thead class="bg-red-50">
                        <tr>
                          <th class="px-2 py-1 text-left text-xs font-medium text-red-700">Row</th>
                          <th class="px-2 py-1 text-left text-xs font-medium text-red-700">
                            Message
                          </th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-red-100">
                        <tr :for={e <- Enum.take(@csv_errors, 25)}>
                          <td class="px-2 py-1 text-xs text-red-800">{e.row}</td>
                          <td class="px-2 py-1 text-xs text-red-800">{e.message}</td>
                        </tr>
                      </tbody>
                    </table>
                    <div :if={length(@csv_errors) > 25} class="mt-1 text-xs text-stone-600">
                      Showing first 25 errors of {length(@csv_errors)}.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <:footer>
          <div class="flex items-center gap-2">
            <.button
              :if={@wizard_step == :provide}
              type="submit"
              id={@id <> "-next"}
              form="csv-select-form"
              variant={:primary}
            >
              Next
            </.button>
            <.button
              :if={@wizard_step == :map and @map_view_tab == :mapping}
              type="submit"
              id={@id <> "-validate"}
              form="csv-mapping-form"
              variant={:primary}
            >
              Verify
            </.button>
            <.button
              :if={@wizard_step == :map}
              id={@id <> "-next-import"}
              type="button"
              phx-target={@myself}
              phx-click="csv_import_final"
              disabled={@csv_errors && @csv_errors != []}
              variant={:primary}
            >
              Next
            </.button>
            <.button
              :if={@wizard_step == :import}
              id={@id <> "-run-import"}
              type="button"
              phx-target={@myself}
              phx-click="csv_run_import"
              variant={:primary}
            >
              Import
            </.button>
            <.button variant={:outline} type="button" phx-target={@myself} phx-click="wizard_close">
              Close
            </.button>
          </div>
        </:footer>
      </.modal>
    </div>
    """
  end

  # Events
  @impl true
  def handle_event("wizard_close", _params, socket) do
    send(self(), {:import_modal, :closed})
    {:noreply, assign(socket, :show, false)}
  end

  @impl true
  def handle_event("wizard_goto", %{"step" => label}, socket) do
    target = wizard_step_from_label(label)
    current = socket.assigns.wizard_step
    steps = [:provide, :map, :import]
    current_idx = Enum.find_index(steps, &(&1 == current)) || 0
    target_idx = Enum.find_index(steps, &(&1 == target)) || 0

    socket = if target_idx < current_idx, do: assign(socket, :wizard_step, target), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_set_tab", %{"tab" => tab}, socket) do
    tab =
      case tab do
        "errors" -> :errors
        "mapping" -> :mapping
        _ -> :preview
      end

    {:noreply, assign(socket, :map_view_tab, tab)}
  end

  @impl true
  def handle_event("csv_import", params, socket) do
    entity = params["entity"] || socket.assigns.entity || "products"
    delimiter = params["delimiter"] || ","
    dry_run? = params["dry_run"] in [true, "true", "on", "1"]
    content = params["csv_content"] || ""

    cond do
      dry_run? and String.trim(content) != "" ->
        do_csv_preview(entity, content, delimiter, socket)

      dry_run? ->
        case consume_uploaded_csv(socket) do
          {:ok, csv_content} ->
            do_csv_preview(entity, csv_content, delimiter, socket)

          :error ->
            {:noreply, put_flash(socket, :info, "Upload a file or paste CSV content for dry run.")}
        end

      true ->
        {:noreply, put_flash(socket, :info, "Upload a file or paste CSV content for dry run.")}
    end
  end

  @impl true
  def handle_event("csv_validate", %{"mapping" => mapping_params}, socket) do
    entity = socket.assigns[:csv_entity] || (socket.assigns.entity || "products")
    mapping = normalize_mapping_params(mapping_params)

    case socket.assigns[:csv_preview] do
      nil -> {:noreply, put_flash(socket, :error, "No CSV preview available")}
      csv -> do_csv_dry_run(entity, csv, socket.assigns[:csv_delimiter] || ",", mapping, socket)
    end
  end

  @impl true
  def handle_event("csv_import_final", _params, socket) do
    {:noreply, assign(socket, :wizard_step, :import)}
  end

  @impl true
  def handle_event("csv_run_import", _params, socket) do
    entity = socket.assigns[:csv_entity] || (socket.assigns.entity || "products")
    mapping = socket.assigns[:csv_mapping] || %{}
    delimiter = socket.assigns[:csv_delimiter] || ","
    csv = socket.assigns[:csv_preview]

    cfg = entity_config(entity)
    importer = cfg.importer

    cond do
      is_nil(csv) ->
        {:noreply, put_flash(socket, :error, "No CSV to import. Run Verify first.")}

      importer && function_exported?(importer, :import, 2) ->
        actor = socket.assigns[:current_user]

        case importer.import(csv, delimiter: delimiter, mapping: mapping, actor: actor) do
          {:ok, %{inserted: ins, updated: upd, errors: errors}} ->
            msg = "Imported #{ins + upd} (#{ins} new#{(upd > 0 && ", #{upd} updated") || ""})."

            {:noreply,
             socket
             |> assign(:csv_errors, errors)
             |> assign(:dry_run_summary, msg)
             |> assign(:wizard_step, :import)
             |> put_flash(:info, msg)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Import failed: #{inspect(reason)}")}
        end

      true ->
        {:noreply, put_flash(socket, :error, "Import not available for #{cfg.label}")}
    end
  end

  # Helpers
  defp wizard_step_from_label(label) do
    case String.downcase(to_string(label)) do
      "provide csv" -> :provide
      "mapping" -> :map
      "import" -> :import
      _ -> :provide
    end
  end

  defp wizard_label(step) do
    case step do
      :provide -> "Provide CSV"
      :map -> "Mapping"
      :import -> "Import"
      _ -> "Provide CSV"
    end
  end

  defp do_csv_preview(entity, csv, delimiter, socket) do
    headers =
      csv
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false, separator: delimiter)
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
     |> assign(:show, true)}
  end

  defp do_csv_dry_run(entity, csv, delimiter, mapping, socket) do
    cfg = entity_config(entity)
    importer = cfg.importer

    if importer && function_exported?(importer, :dry_run, 2) do
      {:ok, %{rows: rows, errors: errors}} =
        importer.dry_run(csv, delimiter: delimiter, mapping: mapping)

      msg = "Dry run: #{length(rows)} rows valid, #{length(errors)} errors"

      {:noreply,
       socket
       |> assign(:dry_run_summary, msg)
       |> assign(:csv_errors, errors)
       |> assign(:map_view_tab, if(errors == [], do: :preview, else: :errors))
       |> assign(:wizard_step, :map)}
    else
      {:noreply, put_flash(socket, :error, "Dry-run not available for #{cfg.label}")}
    end
  end

  defp consume_uploaded_csv(socket) do
    entries = (socket.assigns.uploads[:csv] && socket.assigns.uploads.csv.entries) || []

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

  defp default_mapping_for(entity, headers) do
    cfg = entity_config(entity)
    norm = Enum.map(headers || [], &String.downcase(to_string(&1)))

    Enum.reduce(cfg.fields, %{}, fn f, acc ->
      candidates = cfg.default_candidates[f.name] || []
      val = find_header(norm, candidates) || (f.required && nil) || ""
      Map.put(acc, f.name, val)
    end)
  end

  defp find_header(norm_headers, candidates) do
    Enum.find(norm_headers, fn h -> h in candidates end)
  end

  defp normalize_mapping_params(params) do
    Map.new(params, fn {k, v} -> {k, String.downcase(to_string(v || ""))} end)
  end

  # Static per-entity configuration
  defp entity_config(nil), do: entity_config("products")

  defp entity_config(entity) when is_atom(entity), do: entity |> Atom.to_string() |> entity_config()

  defp entity_config("products") do
    %{
      key: "products",
      label: "Products",
      importer: Craftplan.CSV.Importers.Products,
      instructions: ["Required: name, sku, price. Optional: status."],
      fields: [
        %{name: "name", label: "Name", required: true},
        %{name: "sku", label: "SKU", required: true},
        %{name: "price", label: "Price", required: true},
        %{name: "status", label: "Status", required: false}
      ],
      default_candidates: %{
        "name" => ["name", "product name"],
        "sku" => ["sku", "code"],
        "price" => ["price", "cost", "amount"],
        "status" => ["status"]
      }
    }
  end

  defp entity_config("materials") do
    %{
      key: "materials",
      label: "Materials",
      importer: Craftplan.CSV.Importers.Materials,
      instructions: ["Required: name, sku, unit, price."],
      fields: [
        %{name: "name", label: "Name", required: true},
        %{name: "sku", label: "SKU", required: true},
        %{name: "unit", label: "Unit", required: true},
        %{name: "price", label: "Price", required: true}
      ],
      default_candidates: %{
        "name" => ["name"],
        "sku" => ["sku", "code"],
        "unit" => ["unit", "uom", "units"],
        "price" => ["price", "cost", "amount"]
      }
    }
  end

  defp entity_config("customers") do
    %{
      key: "customers",
      label: "Customers",
      importer: Craftplan.CSV.Importers.Customers,
      instructions: ["Required: type, first_name, last_name, email."],
      fields: [
        %{name: "type", label: "Type", required: true},
        %{name: "first_name", label: "First name", required: true},
        %{name: "last_name", label: "Last name", required: true},
        %{name: "email", label: "Email", required: true}
      ],
      default_candidates: %{
        "type" => ["type"],
        "first_name" => ["first_name", "firstname", "first name"],
        "last_name" => ["last_name", "lastname", "last name"],
        "email" => ["email", "email address"]
      }
    }
  end
end
