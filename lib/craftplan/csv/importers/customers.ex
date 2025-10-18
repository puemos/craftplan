defmodule Craftplan.CSV.Importers.Customers do
  @moduledoc """
  CSV importer for customers (dry-run + import).
  Expected headers: type, first_name, last_name, email.
  """

  alias NimbleCSV.RFC4180, as: CSV

  @type row :: %{
          type: :individual | :business,
          first_name: String.t(),
          last_name: String.t(),
          email: String.t()
        }
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
  Import customers from CSV content. Options: :delimiter, :mapping, :actor.
  Returns {:ok, %{inserted: n, updated: n, errors: errors}}.
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
                  type: row.type,
                  first_name: row.first_name,
                  last_name: row.last_name,
                  email: row.email
                }

                case upsert_customer(attrs, actor) do
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

  defp upsert_customer(attrs, actor) do
    case Craftplan.CRM.get_customer_by_email(attrs.email, actor: actor) do
      {:ok, customer} ->
        case Ash.update(customer, attrs, actor: actor) do
          {:ok, _} -> {:ok, :updated}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        case Ash.create(Craftplan.CRM.Customer, attrs, actor: actor) do
          {:ok, _} -> {:ok, :inserted}
          {:error, reason} -> {:error, reason}
        end
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

  defp apply_mapping(header_map, mapping) when mapping == %{}, do: header_map

  defp apply_mapping(header_map, mapping) do
    Enum.reduce(["type", "first_name", "last_name", "email"], header_map, fn field, acc ->
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
    type_str = fields |> fetch_field(header_map, "type") |> to_string() |> String.trim()
    first_name = fields |> fetch_field(header_map, "first_name") |> to_string() |> String.trim()
    last_name = fields |> fetch_field(header_map, "last_name") |> to_string() |> String.trim()
    email = fields |> fetch_field(header_map, "email") |> to_string() |> String.trim()

    with {:ok, type} <- parse_type(type_str),
         :ok <- present?(first_name, "first_name"),
         :ok <- present?(last_name, "last_name"),
         {:ok, email} <- parse_email(email) do
      {:ok, %{type: type, first_name: first_name, last_name: last_name, email: email}}
    end
  end

  defp parse_type(str) do
    case String.downcase(str) do
      "individual" -> {:ok, :individual}
      "business" -> {:ok, :business}
      "" -> {:error, "Missing type"}
      other -> {:error, "Invalid type: #{other}"}
    end
  end

  defp parse_email(""), do: {:error, "Missing email"}

  defp parse_email(email) do
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email) do
      {:ok, String.downcase(email)}
    else
      {:error, "Invalid email: #{email}"}
    end
  end

  defp present?("", field), do: {:error, "Missing #{field}"}
  defp present?(_val, _field), do: :ok
end
