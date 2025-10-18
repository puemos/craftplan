defmodule CraftplanWeb.InventoryLive.FormComponentMovement do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="movement-movment-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mb-4">
          <div class="mb-2">
            <div class="flex items-center">
              <button
                type="button"
                phx-click="toggle_adjustment_type"
                phx-value-type="set_total"
                phx-target={@myself}
                class={[
                  @adjustment_type == "set_total" && "bg-stone-200 text-stone-800",
                  @adjustment_type != "set_total" && "bg-stone-50 text-stone-700 hover:bg-stone-100",
                  "flex cursor-pointer items-center rounded-l-md border-y border-l border-stone-300 px-3 py-1 text-xs font-medium disabled:cursor-default disabled:bg-stone-100 disabled:text-stone-400"
                ]}
              >
                Set Total
              </button>
              <button
                type="button"
                phx-click="toggle_adjustment_type"
                phx-value-type="add"
                phx-target={@myself}
                class={[
                  @adjustment_type == "add" && "bg-stone-200 text-stone-800",
                  @adjustment_type != "add" && "bg-stone-50 text-stone-700 hover:bg-stone-100",
                  "flex cursor-pointer items-center border-y border-stone-300 px-3 py-1 text-xs font-medium disabled:cursor-default disabled:bg-stone-100 disabled:text-stone-400"
                ]}
              >
                Add
              </button>
              <button
                type="button"
                phx-click="toggle_adjustment_type"
                phx-value-type="subtract"
                phx-target={@myself}
                class={[
                  @adjustment_type == "subtract" && "bg-stone-200 text-stone-800",
                  @adjustment_type != "subtract" && "bg-stone-50 text-stone-700 hover:bg-stone-100",
                  "flex cursor-pointer items-center rounded-r-md border-y border-r border-stone-300 px-3 py-1 text-xs font-medium disabled:cursor-default disabled:bg-stone-100 disabled:text-stone-400"
                ]}
              >
                Subtract
              </button>
            </div>
          </div>
        </div>

        <div :if={@adjustment_type == "add" || @adjustment_type == "subtract"}>
          <.focus_wrap id="adjustment_quantity_focus_wrap">
            <.input
              field={@form[:quantity]}
              type="number"
              min="0"
              label="Quantity"
              inline_label={@material.unit}
              phx-change="validate"
              id="adjustment_quantity"
            />
          </.focus_wrap>
          <.input field={@form[:operation]} type="hidden" value={@adjustment_type} />
        </div>

        <div :if={@adjustment_type == "set_total"}>
          <.input
            field={@form[:quantity]}
            type="number"
            min="0"
            label="New Total"
            inline_label={@material.unit}
            phx-change="validate"
          />
        </div>

        <.input field={@form[:reason]} type="textarea" label="Notes" class="mt-3" />
        <.input field={@form[:material_id]} type="hidden" value={@material.id} />

        <div class="mt-4 rounded-md border border-stone-200 bg-stone-50 p-3 text-stone-700">
          <div class="text-sm">
            <span :if={is_number(@calculated_new_total)}>
              <span class="font-medium">New stock will be:</span>
              <span class="font-bold text-stone-900">
                {format_amount(@material.unit, @calculated_new_total)}
              </span>
            </span>
            <span :if={!is_number(@calculated_new_total)}>
              Enter a quantity to see the new stock level
            </span>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">
            Save
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(adjustment_type: "set_total")
     |> assign(:calculated_new_total, nil)
     |> assign_form()}
  end

  @impl true
  def handle_event("toggle_adjustment_type", %{"type" => adjustment_type}, socket) do
    quantity = parse_integer(socket.assigns.form.params["quantity"])
    calculated_new_total = calculate_new_total(socket, adjustment_type, quantity)

    {:noreply, assign(socket, adjustment_type: adjustment_type, calculated_new_total: calculated_new_total)}
  end

  @impl true
  def handle_event("validate", %{"movement" => movement_params}, socket) do
    quantity = parse_integer(movement_params["quantity"])
    calculated_new_total = calculate_new_total(socket, socket.assigns.adjustment_type, quantity)

    {:noreply,
     socket
     |> assign(form: Form.validate(socket.assigns.form, movement_params))
     |> assign(:calculated_new_total, calculated_new_total)}
  end

  def handle_event("save", %{"movement" => movement_params}, socket) do
    movement_params = prepare_movement_params(movement_params, socket.assigns.adjustment_type)

    case Form.submit(socket.assigns.form, params: movement_params) do
      {:ok, movement} ->
        send(self(), {:saved, movement})

        {:noreply,
         socket
         |> put_flash(:info, "Material #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp calculate_new_total(socket, adjustment_type, quantity) do
    current_quantity = socket.assigns.material.current_stock

    case adjustment_type do
      "add" ->
        if is_integer(quantity) do
          result = Decimal.add(current_quantity, quantity)
          Decimal.to_float(result)
        end

      "subtract" ->
        if is_integer(quantity) do
          result = Decimal.sub(current_quantity, quantity)
          result = if Decimal.compare(result, 0) == :lt, do: Decimal.new(0), else: result
          Decimal.to_float(result)
        end

      "set_total" ->
        if is_integer(quantity), do: quantity * 1.0
    end
  end

  defp prepare_movement_params(params, adjustment_type) when adjustment_type in ["add", "subtract"] do
    quantity = String.to_integer(params["quantity"] || "0")

    quantity =
      case adjustment_type do
        "subtract" -> -quantity
        _ -> quantity
      end

    Map.put(params, "quantity", to_string(quantity))
  end

  defp prepare_movement_params(params, _), do: params

  defp assign_form(socket) do
    form =
      Form.for_create(Inventory.Movement, :adjust_stock,
        as: "movement",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(_), do: nil
end
