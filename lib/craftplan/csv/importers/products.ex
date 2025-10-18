defmodule Craftplan.CSV.Importers.Products do
  @moduledoc """
  CSV importer for products (dry-run supported).
  Expected headers: name, sku, price, status (optional).
  """

  alias NimbleCSV.RFC4180, as: CSV
  alias Craftplan.Catalog.Product.Types.Status

  @type row :: %{name: String.t(), sku: String.t(), price: Decimal.t(), status: atom()}
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
      [] -> {:ok, %{rows: [], errors: []}}
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

  defp header_index_map(headers) do
    headers
    |> Enum.with_index()
    |> Enum.into(%{}, fn {h, i} -> {String.downcase(String.trim(to_string(h))), i} end)
  end

  defp normalize_mapping(mapping) when is_map(mapping) do
    mapping
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), (is_binary(v) && String.downcase(String.trim(v))) || nil} end)
  end

  # Transform the header map to resolve target field names to actual column indices
  # mapping: %{"name" => "product name", "sku" => "code", ...}
  defp apply_mapping(header_map, mapping) when mapping == %{}, do: header_map
  defp apply_mapping(header_map, mapping) do
    # For each known field, if a mapped header exists, point the key to that index too
    Enum.reduce(["name", "sku", "price", "status"], header_map, fn field, acc ->
      case Map.get(mapping, field) do
        nil -> acc
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
    name = fetch_field(fields, header_map, "name") |> to_string() |> String.trim()
    sku = fetch_field(fields, header_map, "sku") |> to_string() |> String.trim()
    price_str = fetch_field(fields, header_map, "price") |> to_string() |> String.trim()
    status_str = fetch_field(fields, header_map, "status") |> to_string() |> String.trim()

    with :ok <- present?(name, "name"),
         :ok <- present?(sku, "sku"),
         {:ok, price} <- parse_decimal(price_str),
         {:ok, status} <- parse_status(status_str) do
      {:ok, %{name: name, sku: sku, price: price, status: status}}
    else
      {:error, msg} -> {:error, msg}
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
