defmodule Craftplan.BottleImport.Upserts do
  @moduledoc false

  alias Craftplan.BottleImport.NameParser
  alias Craftplan.BottleImport.PhoneNormalizer
  alias Craftplan.BottleImport.SlotTimeParser
  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  require Ash.Query

  @spec upsert_customer(map(), term()) :: {:ok, Customer.t()} | {:error, term()}
  def upsert_customer(row, actor) do
    with {:ok, phone} <- PhoneNormalizer.normalize(row["Phone"]) do
      names = NameParser.parse(row["Customer Name"])
      email = blank_to_nil(row["Email"]) |> resolve_email_conflict(phone, actor)

      attrs = %{
        type: :individual,
        first_name: names.first_name,
        last_name: names.last_name,
        email: email,
        phone: phone,
        shipping_address: build_address(row)
      }

      case lookup_customer_by_phone(phone, actor) do
        nil ->
          Customer
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create(actor: actor)

        %Customer{} = existing ->
          existing
          |> Ash.Changeset.for_update(:update, Map.drop(attrs, [:type]))
          |> Ash.update(actor: actor)
      end
    end
  end

  # If `email` is already taken by a customer with a different phone (households
  # share an email), return nil so we don't collide with the email identity.
  defp resolve_email_conflict(nil, _phone, _actor), do: nil

  defp resolve_email_conflict(email, phone, actor) do
    Customer
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, %Customer{phone: ^phone}} -> email
      {:ok, %Customer{}} -> nil
      _ -> email
    end
  end

  @spec resolve_product(String.t(), String.t(), String.t(), map(), term()) ::
          {:ok, Product.t()} | {:error, {:unknown_pid, map()}}
  def resolve_product(pid, name, category, price_map, actor) do
    sku = "BOTTLE-#{pid}"

    case lookup_product_by_sku(sku, actor) do
      %Product{} = found ->
        {:ok, found}

      nil ->
        case Map.get(price_map, pid) do
          nil ->
            {:error, {:unknown_pid, %{pid: pid, name: name}}}

          %Decimal{} = price ->
            create_product(sku, name, category, price, actor)
        end
    end
  end

  @spec upsert_order(map(), [map()], map(), term()) ::
          {:ok, Order.t()} | {:skip, :already_imported} | {:error, term()}
  def upsert_order(order_row, items, price_map, actor) do
    invoice_number = "BOTTLE-#{order_row["Bottle ID"]}"

    case lookup_order_by_invoice(invoice_number, actor) do
      %Order{} ->
        {:skip, :already_imported}

      nil ->
        with {:ok, customer} <- upsert_customer(order_row, actor),
             {:ok, resolved_items} <- resolve_items(items, price_map, actor),
             {:ok, delivery_date} <-
               SlotTimeParser.parse(
                 parse_date(order_row["Fulfillment Slot Day"]),
                 order_row["Fulfillment Slot Time"]
               ) do
          item_params =
            Enum.map(resolved_items, fn {product, qty} ->
              %{product_id: product.id, quantity: qty, unit_price: product.price}
            end)

          attrs = %{
            customer_id: customer.id,
            delivery_date: delivery_date,
            delivery_method: map_delivery_method(order_row["Fulfillment Method"]),
            invoice_number: invoice_number,
            status: :completed,
            payment_method: :card,
            items: item_params
          }

          # Create the order with items via the managed :items relationship.
          # payment_status and paid_at are not in the :create accept list, so we
          # patch them via force_change_attribute on a follow-up :update call.
          with {:ok, order} <-
                 Order
                 |> Ash.Changeset.for_create(:create, attrs)
                 |> Ash.create(actor: actor) do
            order
            |> Ash.Changeset.for_update(:update, %{})
            |> Ash.Changeset.force_change_attribute(:payment_status, :paid)
            |> Ash.Changeset.force_change_attribute(
              :paid_at,
              parse_utc_datetime(order_row["Transaction Date"])
            )
            |> Ash.update(actor: actor)
          end
        end
    end
  end

  # ---------- private helpers ----------

  defp resolve_items(items, price_map, actor) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case resolve_product(
             item["pid"],
             item["product_name"] || "",
             "manufactured",
             price_map,
             actor
           ) do
        {:ok, product} -> {:cont, {:ok, acc ++ [{product, to_decimal(item["quantity"])}]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(s) when is_binary(s), do: Decimal.new(s)

  defp lookup_customer_by_phone(phone, actor) do
    Customer
    |> Ash.Query.filter(phone == ^phone)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp lookup_product_by_sku(sku, actor) do
    Product
    |> Ash.Query.filter(sku == ^sku)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, p} -> p
      _ -> nil
    end
  end

  defp lookup_order_by_invoice(invoice_number, actor) do
    Order
    |> Ash.Query.filter(invoice_number == ^invoice_number)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, o} -> o
      _ -> nil
    end
  end

  defp create_product(sku, name, category, price, actor) do
    availability = if category == "kit", do: :off, else: :available

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      status: :active,
      selling_availability: availability
    })
    |> Ash.create(actor: actor)
  end

  # Address is stored as an embedded resource — Ash accepts a plain map.
  defp build_address(row) do
    street =
      [blank_to_nil(row["Address1"]), blank_to_nil(row["Address2"])]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    %{
      street: blank_to_nil(street),
      city: blank_to_nil(row["City"]),
      state: blank_to_nil(row["State"]),
      zip: blank_to_nil(row["Zip"]),
      country: "US"
    }
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s) when is_binary(s), do: if(String.trim(s) == "", do: nil, else: s)
  defp blank_to_nil(other), do: other

  defp map_delivery_method("Maketto Pickup"), do: :pickup
  defp map_delivery_method(_), do: :delivery

  defp parse_date(%Date{} = d), do: d
  defp parse_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
  defp parse_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp parse_date(s) when is_binary(s), do: Date.from_iso8601!(s)

  defp parse_utc_datetime(nil), do: nil
  defp parse_utc_datetime(%DateTime{} = dt), do: DateTime.shift_zone!(dt, "Etc/UTC")

  defp parse_utc_datetime(%NaiveDateTime{} = ndt) do
    {:ok, dt} = DateTime.from_naive(ndt, "America/New_York")
    DateTime.shift_zone!(dt, "Etc/UTC")
  end

  defp parse_utc_datetime(s) when is_binary(s) do
    case String.trim(s) do
      "" ->
        nil

      trimmed ->
        case NaiveDateTime.from_iso8601(trimmed) do
          {:ok, ndt} -> parse_utc_datetime(ndt)
          {:error, _} -> nil
        end
    end
  end
end
