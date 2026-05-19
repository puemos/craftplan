defmodule CraftplanWeb.InventoryLive.FormComponentMovement do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Inventory
  alias Decimal, as: D

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:mode, fn -> :add end)
     |> assign_new(:calculated_new_total, fn -> nil end)
     |> assign_new(:form, fn -> build_form(assigns.current_user) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="movement-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mb-4">
          <div class="inline-flex rounded-md border border-stone-300">
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="add"
              phx-target={@myself}
              class={[
                "rounded-l-md px-4 py-1.5 text-xs font-medium transition-colors",
                @mode == :add && "bg-stone-800 text-white",
                @mode != :add && "bg-white text-stone-600 hover:bg-stone-50"
              ]}
            >
              Add
            </button>
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="subtract"
              phx-target={@myself}
              class={[
                "rounded-r-md border-l border-stone-300 px-4 py-1.5 text-xs font-medium transition-colors",
                @mode == :subtract && "bg-stone-800 text-white",
                @mode != :subtract && "bg-white text-stone-600 hover:bg-stone-50"
              ]}
            >
              Subtract
            </button>
          </div>
        </div>

        <.input
          field={@form[:quantity]}
          type="number"
          min="0"
          step="any"
          label={if @mode == :add, do: "Quantity to add", else: "Quantity to subtract"}
          inline_label={@material.unit}
          id="movement-quantity"
        />

        <.input field={@form[:reason]} type="textarea" label="Notes" class="mt-3" />
        <.input field={@form[:material_id]} type="hidden" value={@material.id} />

        <div class="mt-4 rounded-md border border-stone-200 bg-stone-50 p-3 text-sm text-stone-700">
          <%= if @calculated_new_total do %>
            <span class="font-medium">New stock will be: </span>
            <span class={[
              "font-bold",
              negative?(@calculated_new_total) && "text-red-600",
              !negative?(@calculated_new_total) && "text-stone-900"
            ]}>
              {format_preview(@material.unit, @calculated_new_total)}
            </span>
          <% else %>
            Enter a quantity to see the new stock level
          <% end %>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    quantity = parse_quantity(socket.assigns.form.params["quantity"])
    current_stock = socket.assigns.material.current_stock

    {:noreply,
     socket
     |> assign(:mode, mode)
     |> assign(:calculated_new_total, new_total(current_stock, mode, quantity))}
  end

  @impl true
  def handle_event("validate", %{"movement" => params}, socket) do
    quantity = parse_quantity(params["quantity"])
    current_stock = socket.assigns.material.current_stock

    {:noreply,
     socket
     |> assign(:form, Form.validate(socket.assigns.form, params))
     |> assign(:calculated_new_total, new_total(current_stock, socket.assigns.mode, quantity))}
  end

  @impl true
  def handle_event("save", %{"movement" => params}, socket) do
    params = sign_quantity(params, socket.assigns.mode)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, movement} ->
        send(self(), {:saved, movement})

        {:noreply,
         socket
         |> put_flash(:info, "Stock adjustment recorded")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp new_total(_current_stock, _mode, nil), do: nil
  defp new_total(current_stock, :add, quantity), do: D.add(current_stock, quantity)
  defp new_total(current_stock, :subtract, quantity), do: D.sub(current_stock, quantity)

  defp sign_quantity(params, :subtract) do
    case parse_quantity(params["quantity"]) do
      nil -> params
      qty -> Map.put(params, "quantity", D.to_string(D.negate(qty)))
    end
  end

  defp sign_quantity(params, :add), do: params

  defp parse_quantity(value) when is_binary(value) and value != "" do
    case D.parse(value) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp parse_quantity(_), do: nil

  defp negative?(value), do: D.compare(value, D.new(0)) == :lt

  defp format_preview(unit, %D{} = value) do
    format_amount(unit, D.to_float(value))
  end

  defp build_form(current_user) do
    Inventory.Movement
    |> Form.for_create(:adjust_stock,
      as: "movement",
      actor: current_user
    )
    |> to_form()
  end
end
