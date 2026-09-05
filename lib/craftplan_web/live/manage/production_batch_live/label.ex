defmodule CraftplanWeb.ProductionBatchLive.Label do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Orders
  alias Craftplan.Production.BatchLabel

  @impl true
  def mount(%{"batch_code" => batch_code}, _session, socket) do
    actor = socket.assigns[:current_user]

    batch =
      Orders.get_production_batch_by_code!(%{batch_code: batch_code},
        actor: actor,
        load: [product: [:name, :sku, :allergens, :nutritional_facts]]
      )

    snapshot = BatchLabel.data(batch, actor)

    {:ok,
     socket
     |> assign(:page_title, "Label #{batch.batch_code}")
     |> assign(:batch, batch)
     |> assign(:snapshot, snapshot)
     |> assign(:ingredients, BatchLabel.ingredients(snapshot))
     |> assign(:allergens, BatchLabel.allergens(snapshot))
     |> assign(:nutrition_facts, BatchLabel.nutrition_facts(snapshot))
     |> assign(:barcode, BatchLabel.barcode(batch.batch_code))
     |> assign(:label_size, :a5)}
  end

  @impl true
  def handle_event("set_label_size", %{"size" => "compact"}, socket) do
    {:noreply, assign(socket, :label_size, :compact)}
  end

  def handle_event("set_label_size", _params, socket) do
    {:noreply, assign(socket, :label_size, :a5)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl print:max-w-none">
      <div class="mb-5 flex flex-col gap-4 print:hidden sm:flex-row sm:items-center sm:justify-between">
        <div>
          <.link
            navigate={~p"/manage/production/batches/#{@batch.batch_code}"}
            class="inline-flex items-center gap-1 text-sm text-stone-500 hover:text-stone-900"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to batch
          </.link>
          <h1 class="mt-2 text-xl font-semibold text-stone-900">Batch label preview</h1>
          <p class="mt-1 text-sm text-stone-600">
            Values are frozen from the batch record. Choose a print format before printing.
          </p>
        </div>
        <div class="flex items-center gap-2 sm:self-end">
          <div
            id="label-size-selector"
            class="inline-flex rounded-lg border border-stone-300 bg-white p-1"
          >
            <button
              type="button"
              phx-click="set_label_size"
              phx-value-size="compact"
              class={[
                "transition-[background-color,color,box-shadow,transform] rounded-md px-3 py-1.5 text-sm duration-150 active:scale-[0.98]",
                if(@label_size == :compact,
                  do: "bg-indigo-50 text-indigo-700 shadow-sm ring-1 ring-indigo-100",
                  else: "text-stone-600 hover:bg-stone-100"
                )
              ]}
            >
              Compact
            </button>
            <button
              type="button"
              phx-click="set_label_size"
              phx-value-size="a5"
              class={[
                "transition-[background-color,color,box-shadow,transform] rounded-md px-3 py-1.5 text-sm duration-150 active:scale-[0.98]",
                if(@label_size == :a5,
                  do: "bg-indigo-50 text-indigo-700 shadow-sm ring-1 ring-indigo-100",
                  else: "text-stone-600 hover:bg-stone-100"
                )
              ]}
            >
              A5
            </button>
          </div>
          <.button id="print-batch-label" variant={:primary} onclick="window.print()">
            <.icon name="hero-printer" class="h-4 w-4" /> Print label
          </.button>
        </div>
      </div>

      <div
        :if={!label_ready?(@snapshot)}
        id="label-setup-warning"
        class="mb-5 flex items-start justify-between gap-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900 print:hidden"
      >
        <div class="flex gap-3">
          <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 flex-none" />
          <div>
            <p class="font-semibold">Complete the label setup before using this on packaged food.</p>
            <p class="mt-1 text-amber-800">
              Missing: {Enum.join(missing_label_fields(@snapshot), ", ")}.
            </p>
          </div>
        </div>
        <.link
          navigate={~p"/manage/products/#{BatchLabel.sku(@snapshot)}/edit"}
          class="whitespace-nowrap font-medium text-amber-900 underline"
        >
          Edit product
        </.link>
      </div>

      <div class="rounded-xl border border-stone-200 bg-stone-50 p-4 print:border-0 print:bg-white print:p-0 sm:p-8">
        <article
          id="batch-product-label"
          class={[
            "mx-auto border border-stone-300 bg-white text-stone-950 shadow-sm print:m-0 print:max-w-full print:border-0 print:p-0 print:shadow-none",
            if(@label_size == :compact, do: "max-w-xl p-6", else: "max-w-3xl p-8 sm:p-10")
          ]}
        >
          <header class="border-b-2 border-stone-950 pb-5">
            <div class={[
              if(@label_size == :compact,
                do: "space-y-4",
                else: "flex items-start justify-between gap-6"
              )
            ]}>
              <div class="min-w-0">
                <p class="tracking-[0.18em] text-xs font-bold uppercase text-stone-500">
                  {BatchLabel.food_business_name(@snapshot) || "Finished product"}
                </p>
                <h2 class="mt-2 text-3xl font-bold leading-tight tracking-tight">
                  {BatchLabel.product_name(@snapshot)}
                </h2>
                <p class="mt-1 text-sm text-stone-500">SKU {BatchLabel.sku(@snapshot)}</p>
              </div>
              <div class={[
                "rounded-lg border-2 border-stone-900 px-3 py-2",
                if(@label_size == :compact,
                  do: "flex items-center justify-between gap-3 text-left",
                  else: "shrink-0 text-right"
                )
              ]}>
                <p class="text-[10px] font-bold uppercase tracking-wider">Lot</p>
                <p id="label-batch-code" class="font-mono mt-0.5 break-all text-sm font-bold">
                  L {@batch.batch_code}
                </p>
              </div>
            </div>

            <div class="mt-5 grid grid-cols-3 divide-x divide-stone-300 border-y border-stone-300 py-3 text-center">
              <.label_fact label="Net quantity" value={net_quantity_label(@snapshot)} />
              <.label_fact
                label={durability_label(@snapshot)}
                value={best_before_label(@batch, @snapshot)}
              />
              <.label_fact
                label="Produced"
                value={format_label_date(@batch.completed_at || @batch.inserted_at)}
              />
            </div>
          </header>

          <section :if={@ingredients != []} class="border-b border-stone-300 py-5">
            <h3 class="text-xs font-bold uppercase tracking-wider text-stone-600">Ingredients</h3>
            <p id="label-ingredients" class="mt-2 text-sm leading-6">
              <%= for {ingredient, index} <- Enum.with_index(@ingredients) do %>
                <span class={ingredient_allergen?(ingredient) && "font-extrabold uppercase"}>
                {BatchLabel.value(ingredient, "name", "")}
              </span>{ingredient_separator(
                  index,
                  @ingredients
                )}
              <% end %>
            </p>
            <p :if={@allergens != []} id="label-allergens" class="mt-3 text-sm">
              <span class="font-bold">Allergens:</span>
              <span class="font-extrabold uppercase">{Enum.join(@allergens, ", ")}</span>
            </p>
          </section>

          <section
            :if={nutrition_declaration?(@nutrition_facts)}
            class="border-b border-stone-300 py-5"
          >
            <div class="mb-2 flex items-end justify-between gap-4">
              <h3 class="text-sm font-bold">Nutrition declaration</h3>
              <p class="text-xs text-stone-500">per {nutrition_basis_label(@nutrition_facts)}</p>
            </div>
            <table id="label-nutrition" class="w-full border-collapse text-sm">
              <tbody>
                <tr :for={fact <- @nutrition_facts} class="border-t border-stone-200">
                  <td class="py-1.5 pr-4">
                    <span class={
                      if BatchLabel.value(fact, "parent_key"), do: "pl-4", else: "font-medium"
                    }>
                      {nutrient_label(fact)}
                    </span>
                  </td>
                  <td class="py-1.5 text-right font-medium">{format_nutrition_amount(fact)}</td>
                </tr>
              </tbody>
            </table>
          </section>

          <section class="grid gap-5 py-5 text-sm sm:grid-cols-2">
            <div>
              <h3 class="text-xs font-bold uppercase tracking-wider text-stone-600">Storage</h3>
              <p class="mt-1 leading-5">
                {BatchLabel.storage_instructions(@snapshot) || "Not specified"}
              </p>
            </div>
            <div :if={BatchLabel.country_of_origin(@snapshot)}>
              <h3 class="text-xs font-bold uppercase tracking-wider text-stone-600">Origin</h3>
              <p class="mt-1 leading-5">{BatchLabel.country_of_origin(@snapshot)}</p>
            </div>
            <div class="sm:col-span-2">
              <h3 class="text-xs font-bold uppercase tracking-wider text-stone-600">
                Food business operator
              </h3>
              <p class="mt-1 font-medium">
                {BatchLabel.food_business_name(@snapshot) || "Not specified"}
              </p>
              <p class="text-stone-600">
                {BatchLabel.food_business_address(@snapshot) || "Address not specified"}
              </p>
            </div>
          </section>

          <footer class="border-t-2 border-stone-950 pt-4">
            <svg
              id="label-batch-barcode"
              role="img"
              aria-label={"Code 39 barcode for batch #{@batch.batch_code}"}
              viewBox={"0 0 #{@barcode.width} 52"}
              preserveAspectRatio="none"
              class="h-14 w-full"
            >
              <rect
                :for={bar <- @barcode.bars}
                x={bar.x}
                y="0"
                width={bar.width}
                height="44"
                fill="currentColor"
              />
            </svg>
            <p class="font-mono tracking-[0.2em] mt-1 text-center text-xs">{@batch.batch_code}</p>
          </footer>
        </article>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp label_fact(assigns) do
    ~H"""
    <div class="px-2">
      <p class="text-[10px] font-bold uppercase tracking-wider text-stone-500">{@label}</p>
      <p class="mt-1 text-sm font-bold">{@value}</p>
    </div>
    """
  end

  defp ingredient_allergen?(ingredient) do
    ingredient |> BatchLabel.value("allergens", []) |> Enum.any?()
  end

  defp ingredient_separator(index, ingredients) do
    if index < length(ingredients) - 1, do: ", ", else: "."
  end

  defp label_ready?(snapshot), do: missing_label_fields(snapshot) == []

  defp missing_label_fields(snapshot) do
    [
      {"net quantity", BatchLabel.net_quantity(snapshot)},
      {"shelf life", BatchLabel.shelf_life_days(snapshot)},
      {"storage instructions", BatchLabel.storage_instructions(snapshot)},
      {"business operator", BatchLabel.food_business_name(snapshot)},
      {"business address", BatchLabel.food_business_address(snapshot)}
    ]
    |> Enum.filter(fn {_label, value} -> value in [nil, "", 0, "0"] end)
    |> Enum.map(&elem(&1, 0))
  end

  defp net_quantity_label(snapshot) do
    case {BatchLabel.net_quantity(snapshot), BatchLabel.net_quantity_unit(snapshot)} do
      {nil, _unit} -> "Not set"
      {quantity, "gram"} -> "#{quantity} g"
      {quantity, "kilogram"} -> "#{quantity} kg"
      {quantity, "milliliter"} -> "#{quantity} ml"
      {quantity, "liter"} -> "#{quantity} l"
      {quantity, unit} when is_binary(unit) -> "#{quantity} #{unit}"
      {quantity, _unit} -> quantity
    end
  end

  defp best_before_label(batch, snapshot) do
    date = batch.completed_at || batch.inserted_at

    case {date, BatchLabel.shelf_life_days(snapshot)} do
      {date, days} when is_integer(days) and days > 0 ->
        date |> to_date() |> Date.add(days) |> format_label_date()

      _ ->
        "Not set"
    end
  end

  defp durability_label(snapshot) do
    if BatchLabel.durability_type(snapshot) == "use_by", do: "Use by", else: "Best before"
  end

  defp to_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp to_date(%Date{} = date), do: date

  defp format_label_date(nil), do: "—"
  defp format_label_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")
  defp format_label_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")

  defp nutrition_declaration?(facts) do
    Enum.any?(facts, &BatchLabel.value(&1, "declaration", false))
  end

  defp nutrition_basis_label(facts) do
    case Enum.find(facts, &BatchLabel.value(&1, "declaration", false)) do
      nil ->
        "100 g"

      fact ->
        "#{BatchLabel.value(fact, "per_quantity", "100")} #{unit_label(BatchLabel.value(fact, "per_unit", "gram"))}"
    end
  end

  defp nutrient_label(fact) do
    name = BatchLabel.value(fact, "name", "")

    if BatchLabel.value(fact, "parent_key") do
      "of which #{String.downcase(name)}"
    else
      name
    end
  end

  defp format_nutrition_amount(fact) do
    amount = BatchLabel.decimal_value(fact, "amount")

    "#{Decimal.to_string(Decimal.normalize(amount))} #{unit_label(BatchLabel.value(fact, "unit", "gram"))}"
  end

  defp unit_label("milliliter"), do: "ml"
  defp unit_label("kilojoule"), do: "kJ"
  defp unit_label("kilocalorie"), do: "kcal"
  defp unit_label("milligram"), do: "mg"
  defp unit_label("microgram"), do: "µg"
  defp unit_label("gram"), do: "g"
  defp unit_label(unit), do: unit
end
