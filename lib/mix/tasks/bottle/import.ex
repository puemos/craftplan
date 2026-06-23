defmodule Mix.Tasks.Bottle.Import do
  @moduledoc """
  Imports a Bottle order-report run directory into Craftplan.

      mix bottle.import <run_dir> [--yes] [--price-map PATH]

  The run directory must contain `products.csv`, `customers.csv`, `orders.csv`,
  `order_items.csv` as produced by `priv/imports/bottle/extract.py`.

  Default price map: `priv/imports/bottle/price_map.yml`.
  Pass `--price-map PATH` to override.
  Pass `--yes` (or `-y`) to skip the interactive confirmation prompt.

  Exits non-zero (code 2) if any PIDs in order_items.csv are absent from both
  the price map and the existing product catalogue.
  """
  use Mix.Task

  alias Craftplan.BottleImport.Upserts

  require Ash.Query
  require Logger

  @shortdoc "Import a Bottle order-report run into Craftplan"

  @default_price_map "priv/imports/bottle/price_map.yml"
  @audit_log "priv/imports/bottle/bottle_import_log.jsonl"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    result = run_args(args)
    Mix.shell().info(IO.iodata_to_binary(format_summary(result)))
    if result.unknown_pids != [], do: System.halt(2)
    :ok
  end

  @doc """
  Programmatic entry point used by tests. Returns a result map.
  """
  def run_args(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [yes: :boolean, price_map: :string],
        aliases: [y: :yes]
      )

    [run_dir | _] = positional
    price_map_path = opts[:price_map] || @default_price_map
    yes? = opts[:yes] || false

    price_map = load_price_map(price_map_path)
    csvs = load_csvs(run_dir)

    {preview_result, _} = preview(csvs, price_map)

    if preview_result.unknown_pids != [] do
      summary = %{
        unknown_pids: preview_result.unknown_pids,
        created_customers: 0,
        created_products: 0,
        inserted_orders: 0,
        skipped_orders: 0,
        failed_orders: 0,
        elapsed_ms: 0
      }

      append_audit(summary, run_dir)
      summary
    else
      yes? || confirm!(preview_result)
      execute(csvs, price_map, run_dir)
    end
  end

  # ---------- pipeline ----------

  # preview/2 scans order_items PIDs to detect unknowns before touching the DB.
  # A PID is "known" if it already exists as a BOTTLE- product in the DB, or if
  # the price map has an entry for it (meaning we can create it on demand).
  defp preview(csvs, price_map) do
    actor = staff_actor!()

    unknowns =
      csvs.order_items
      |> Enum.map(& &1["pid"])
      |> Enum.uniq()
      |> Enum.reject(fn pid ->
        sku = "BOTTLE-#{pid}"

        match?(%Craftplan.Catalog.Product{}, lookup_product_by_sku(sku, actor)) or
          Map.has_key?(price_map, pid)
      end)

    {%{unknown_pids: unknowns}, csvs}
  end

  defp lookup_product_by_sku(sku, actor) do
    Craftplan.Catalog.Product
    |> Ash.Query.filter(sku == ^sku)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, p} -> p
      _ -> nil
    end
  end

  # execute/3 — products-first flow:
  #   1. Pre-create products from products.csv with their real category (so kit
  #      products get selling_availability: :off, not the :available default that
  #      resolve_items would otherwise apply).
  #   2. Then iterate orders — resolve_items will find existing products by SKU
  #      and never hit the create-with-hardcoded-category path.
  defp execute(csvs, price_map, run_dir) do
    actor = staff_actor!()

    customers_before = count_all(Craftplan.CRM.Customer, actor)
    products_before = count_all(Craftplan.Catalog.Product, actor)

    started_at = System.monotonic_time(:millisecond)

    # Step 1: pre-create products with correct categories
    Enum.each(csvs.products, fn product_row ->
      Upserts.resolve_product(
        product_row["pid"],
        product_row["name"],
        product_row["category"] || "manufactured",
        price_map,
        actor
      )
    end)

    # Step 2: process orders
    {inserted, skipped, failed} =
      Enum.reduce(csvs.orders, {0, 0, []}, fn order_row, {ins, sk, fl} ->
        items =
          Enum.filter(csvs.order_items, fn item ->
            to_string(item["Bottle ID"]) == to_string(order_row["Bottle ID"])
          end)

        case Upserts.upsert_order(order_row, items, price_map, actor) do
          {:ok, _order} -> {ins + 1, sk, fl}
          {:skip, :already_imported} -> {ins, sk + 1, fl}
          {:error, reason} -> {ins, sk, [{order_row["Bottle ID"], reason} | fl]}
        end
      end)

    elapsed = System.monotonic_time(:millisecond) - started_at

    summary = %{
      unknown_pids: [],
      created_customers: count_all(Craftplan.CRM.Customer, actor) - customers_before,
      created_products: count_all(Craftplan.Catalog.Product, actor) - products_before,
      inserted_orders: inserted,
      skipped_orders: skipped,
      failed_orders: length(failed),
      failures: Enum.reverse(failed),
      elapsed_ms: elapsed
    }

    append_audit(summary, run_dir)
    summary
  end

  defp count_all(resource, actor) do
    {:ok, list} = Ash.read(resource, actor: actor)
    length(list)
  end

  defp confirm!(preview_result) do
    Mix.shell().info("""
    Unknown PIDs: #{length(preview_result.unknown_pids)}
    """)

    if Mix.shell().yes?("Proceed?") do
      true
    else
      Mix.raise("Aborted by user.")
    end
  end

  # ---------- I/O ----------

  defp load_csvs(run_dir) do
    %{
      products: read_csv(Path.join(run_dir, "products.csv")),
      customers: read_csv(Path.join(run_dir, "customers.csv")),
      orders: read_csv(Path.join(run_dir, "orders.csv")),
      order_items: read_csv(Path.join(run_dir, "order_items.csv"))
    }
  end

  defp read_csv(path) do
    [header | rows] =
      path
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
      |> Enum.to_list()

    Enum.map(rows, fn row -> Enum.zip(header, row) |> Map.new() end)
  end

  # Reads the price map YAML. Supports both forms:
  #
  #   prices: {}
  #   prices:
  #     "PID-47420": "10.00"
  #
  # Implemented with a line-by-line scanner to avoid a YAML dependency.
  defp load_price_map(path) do
    case File.read(path) do
      {:ok, body} ->
        body
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          case Regex.run(~r/^\s+"(PID-[\d-]+)":\s*"?([\d.]+)"?\s*$/, line) do
            [_, pid, price] -> Map.put(acc, pid, Decimal.new(price))
            _ -> acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp append_audit(summary, run_dir) do
    File.mkdir_p!(Path.dirname(@audit_log))

    line =
      Jason.encode!(%{
        at: DateTime.utc_now() |> DateTime.to_iso8601(),
        run_dir: run_dir,
        unknown_pids: summary.unknown_pids,
        inserted_orders: summary.inserted_orders,
        skipped_orders: summary.skipped_orders,
        failed_orders: summary.failed_orders,
        elapsed_ms: summary.elapsed_ms
      })

    File.write!(@audit_log, line <> "\n", [:append])
  end

  defp format_summary(s) do
    [
      "Bottle import summary\n",
      "  inserted orders: #{s.inserted_orders}\n",
      "  skipped orders:  #{s.skipped_orders}\n",
      "  failed orders:   #{s.failed_orders}\n",
      "  unknown PIDs:    #{length(s.unknown_pids)}#{format_unknowns(s.unknown_pids)}\n",
      "  elapsed: #{s.elapsed_ms}ms\n"
    ]
  end

  defp format_unknowns([]), do: ""
  defp format_unknowns(list), do: " (" <> Enum.join(list, ", ") <> ")"

  defp staff_actor! do
    Craftplan.Accounts.User
    |> Ash.Query.filter(role in [:staff, :admin])
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
