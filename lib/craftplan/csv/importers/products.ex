defmodule Craftplan.CSV.Importers.Products do
  @moduledoc """
  CSV importer for products (dry-run supported).
  Expected headers: name, sku, price, status (optional).
  """

  alias Craftplan.Catalog.Product.Types.Status
  alias NimbleCSV.RFC4180, as: CSV

  @type row :: %{name: String.t(), sku: String.t(), price: Money.t(), status: atom()}
  @type error :: %{row: non_neg_integer(), message: String.t()}

  @spec dry_run(String.t(), keyword) :: {:ok, %{rows: [row()], errors: [error()]}}
  def dry_run(content, opts \\ []) when is_binary(content) do
    delimiter = Keyword.get(opts, :delimiter, ",")
    mapping = normalize_mapping(Keyword.get(opts, :mapping, %{}))

    parsed =
      content
      |> String.trim()
      |> CSV.parse_string(skip_headers: false, separator: delimiter)

    case parsed do
      [] ->
        {:ok, %{rows: [], errors: []}}

      [headers | data_rows] ->
        header_map =
          headers
          |> header_index_map()
          |> apply_mapping(mapping)

        {rows, errors} =
          data_rows
          |> Enum.with_index(2)
          |> Enum.reduce({[], []}, fn {fields, line}, {acc_rows, acc_errors} ->
            case cast_row(fields, header_map) do
              {:ok, row} -> {[row | acc_rows], acc_errors}
              {:error, msg} -> {acc_rows, [%{row: line, message: msg} | acc_errors]}
            end
          end)

        {:ok, %{rows: Enum.reverse(rows), errors: Enum.reverse(errors)}}
    end
  end

  @doc """
  Import products from CSV content. Returns counts and errors.
  Options:
  - :delimiter - CSV delimiter (default ",")
  - :mapping - map of target fields to header names
  - :actor - Ash actor for authorization
  """
  @spec import(String.t(), keyword) ::
          {:ok, %{inserted: non_neg_integer(), updated: non_neg_integer(), errors: [error()]}}
          | {:error, term}
  def import(content, opts \\ []) when is_binary(content) do
    delimiter = Keyword.get(opts, :delimiter, ",")
    mapping = normalize_mapping(Keyword.get(opts, :mapping, %{}))
    actor = Keyword.get(opts, :actor)

    parsed =
      content
      |> String.trim()
      |> CSV.parse_string(skip_headers: false, separator: delimiter)

    case parsed do
      [] ->
        {:ok, %{inserted: 0, updated: 0, errors: []}}

      [headers | data_rows] ->
        header_map =
          headers
          |> header_index_map()
          |> apply_mapping(mapping)

        {ins, upd, errs} =
          data_rows
          |> Enum.with_index(2)
          |> Enum.reduce({0, 0, []}, fn {fields, line}, {acc_i, acc_u, acc_e} ->
            case cast_row(fields, header_map) do
              {:ok, row} ->
                attrs = %{
                  name: row.name,
                  sku: row.sku,
                  price: row.price,
                  status: row.status,
                  currency: row.currency
                }

                case upsert_product(attrs, actor) do
                  {:ok, :inserted} ->
                    {acc_i + 1, acc_u, acc_e}

                  {:ok, :updated} ->
                    {acc_i, acc_u + 1, acc_e}

                  {:error, reason} ->
                    {acc_i, acc_u, [%{row: line, message: inspect(reason)} | acc_e]}
                end

              {:error, msg} ->
                {acc_i, acc_u, [%{row: line, message: msg} | acc_e]}
            end
          end)

        {:ok, %{inserted: ins, updated: upd, errors: Enum.reverse(errs)}}
    end
  end

  defp upsert_product(attrs, actor) do
    attrs
    |> Map.fetch!(:sku)
    |> Craftplan.Catalog.get_product_by_sku(actor: actor)
    |> do_upsert_product(attrs, actor)
  end

  defp do_upsert_product({:ok, product}, attrs, actor) do
    with {:ok, _} <- Ash.update(product, attrs, actor: actor) do
      {:ok, :updated}
    end
  end

  defp do_upsert_product({:error, _reason}, attrs, actor) do
    with {:ok, _} <- Ash.create(Craftplan.Catalog.Product, attrs, actor: actor) do
      {:ok, :inserted}
    end
  end

  defp header_index_map(headers) do
    headers
    |> Enum.with_index()
    |> Map.new(fn {h, i} -> {String.downcase(String.trim(to_string(h))), i} end)
  end

  defp normalize_mapping(mapping) when is_map(mapping) do
    Map.new(mapping, fn {k, v} ->
      {to_string(k), (is_binary(v) && String.downcase(String.trim(v))) || nil}
    end)
  end

  # Transform the header map to resolve target field names to actual column indices
  # mapping: %{"name" => "product name", "sku" => "code", ...}
  defp apply_mapping(header_map, mapping) when mapping == %{}, do: header_map

  defp apply_mapping(header_map, mapping) do
    # For each known field, if a mapped header exists, point the key to that index too
    Enum.reduce(["name", "sku", "price", "status", "currency"], header_map, fn field, acc ->
      case Map.get(mapping, field) do
        nil ->
          acc

        mapped_header ->
          case Map.fetch(header_map, mapped_header) do
            {:ok, idx} -> Map.put(acc, field, idx)
            :error -> acc
          end
      end
    end)
  end

  defp fetch_field(fields, header_map, key) do
    case Map.fetch(header_map, key) do
      {:ok, idx} -> Enum.at(fields, idx)
      :error -> nil
    end
  end

  defp cast_row(fields, header_map) do
    name = fields |> fetch_field(header_map, "name") |> to_string() |> String.trim()
    sku = fields |> fetch_field(header_map, "sku") |> to_string() |> String.trim()
    currency = fields |> fetch_field(header_map, "currency") |> to_string() |> String.trim()

    price_decimal =
      fields |> fetch_field(header_map, "price") |> Money.new(currency) |> Money.to_decimal()

    status_str = fields |> fetch_field(header_map, "status") |> to_string() |> String.trim()

    with :ok <- present?(name, "name"),
         :ok <- present?(sku, "sku"),
         :ok <- present?(currency, "currency"),
         {:ok, price} <- price_decimal,
         {:ok, status} <- parse_status(status_str) do
      {:ok, %{name: name, sku: sku, price: price, status: status, currency: currency}}
    end
  end

  defp present?("", field), do: {:error, "Missing #{field}"}
  defp present?(_val, _field), do: :ok

  defp parse_decimal(""), do: {:ok, Decimal.new("0")}

  defp parse_decimal(str) do
    case Decimal.parse(str) do
      :error -> {:error, "Invalid price: #{str}"}
      {dec, _} -> {:ok, dec}
    end
  end

  defp parse_status(""), do: {:ok, :active}

  defp parse_status(str) do
    down = String.downcase(str)

    case Enum.find(Status.values(), fn v -> Atom.to_string(v) == down end) do
      nil -> {:error, "Invalid status: #{str}"}
      atom -> {:ok, atom}
    end
  end
end
