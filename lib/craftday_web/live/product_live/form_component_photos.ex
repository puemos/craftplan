defmodule CraftdayWeb.ProductLive.FormComponentPhotos do
  @moduledoc false
  use CraftdayWeb, :live_component

  alias Craftday.Catalog.Product.Photo

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <h3 class="text-lg font-medium">Product Photos</h3>

          <div class="mb-4 hidden">
            <.live_file_input upload={@uploads.photos} />
          </div>
          <label for={@uploads.photos.ref}>
            <section
              phx-drop-target={@uploads.photos.ref}
              class="rounded border-2 border-dashed border-stone-300 p-4"
            >
              <div :if={@upload_warning} class="mb-4 rounded bg-yellow-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg
                      class="h-5 w-5 text-yellow-400"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zm0 10a1 1 0 100-2 1 1 0 000 2z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800">Upload Warning</h3>
                    <div class="mt-2 text-sm text-yellow-700">
                      <p>{@upload_warning}</p>
                    </div>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
                <div
                  :for={entry <- @uploads.photos.entries}
                  class="group relative transition-all duration-200 hover:shadow-md"
                >
                  <div class="overflow-hidden rounded-lg border border-stone-200 bg-white shadow-sm transition-all">
                    <div class="relative">
                      <.live_img_preview
                        entry={entry}
                        class="h-48 w-full object-cover transition-transform duration-200 group-hover:scale-105"
                      />
                      <div class="from-black/40 absolute right-0 bottom-0 left-0 bg-gradient-to-t to-transparent p-3">
                        <p class="truncate text-sm font-medium text-white">
                          {entry.client_name}
                        </p>
                      </div>
                    </div>

                    <div class="p-3">
                      <div class="mb-2">
                        <div class="h-1.5 w-full overflow-hidden rounded-full bg-stone-100">
                          <div
                            style={"width: #{entry.progress}%"}
                            class="h-full rounded-full bg-blue-500 transition-all duration-300"
                          >
                          </div>
                        </div>
                        <p class="mt-1.5 text-xs text-stone-500">
                          {entry.progress}% uploaded
                        </p>
                      </div>

                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        phx-target={@myself}
                        class="mt-1 flex w-full items-center justify-center rounded-md border border-stone-200 px-2 py-1.5 text-xs font-medium text-stone-700 transition-colors hover:bg-stone-50"
                        aria-label="Cancel upload"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="mr-1 h-3.5 w-3.5"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                            clip-rule="evenodd"
                          />
                        </svg>
                        Cancel
                      </button>
                    </div>
                  </div>

                  <div
                    :for={err <- upload_errors(@uploads.photos, entry)}
                    class="mt-2 rounded-md bg-red-50 p-2 text-xs font-medium text-red-500"
                  >
                    {error_to_string(err)}
                  </div>
                </div>
              </div>

              <div :for={err <- upload_errors(@uploads.photos)} class="mt-2 text-sm text-red-500">
                {error_to_string(err)}
              </div>

              <p
                :if={Enum.empty?(@uploads.photos.entries) && Enum.empty?(@product_photos)}
                class="py-4 text-center text-stone-500"
              >
                Drop files here or click to upload
              </p>
            </section>
          </label>
          <div :if={not Enum.empty?(@product_photos) or not Enum.empty?(@uploaded_files)} class="mt-6">
            <h4 class="text-md mb-2 font-medium">Current Photos</h4>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
              <div :for={photo <- @product_photos ++ @uploaded_files} class="relative">
                <div class={[
                  "overflow-hidden rounded border-2",
                  (@form[:featured_photo].value == photo && "border-blue-500") || "border-stone-200"
                ]}>
                  <img src={Photo.url({photo, @product}, :thumb)} class="h-40 w-full object-cover" />

                  <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-40 opacity-0 transition-opacity hover:opacity-100">
                    <div class="flex space-x-2">
                      <button
                        type="button"
                        phx-click="set-featured"
                        phx-value-photo={photo}
                        phx-target={@myself}
                        class="rounded bg-blue-500 px-2 py-1 text-xs text-white"
                      >
                        {if @form[:featured_photo].value == photo,
                          do: "Featured",
                          else: "Set as Featured"}
                      </button>
                      <button
                        type="button"
                        phx-click="remove-photo"
                        phx-value-photo={photo}
                        phx-target={@myself}
                        class="rounded bg-red-500 px-2 py-1 text-xs text-white"
                      >
                        Remove
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save Photos</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:uploaded_files, [])
      |> assign(:product_photos, [])
      |> assign(:removed_photos, [])
      |> assign(:upload_warning, nil)
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 10,
        max_file_size: 10_000_000
      )
      |> assign_form()

    socket =
      if socket.assigns.product do
        product_photos = socket.assigns.product.photos || []
        assign(socket, :product_photos, product_photos)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("set-featured", %{"photo" => photo}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, %{"featured_photo" => photo})
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("remove-photo", %{"photo" => photo}, socket) do
    removed_photos = [photo | socket.assigns.removed_photos]

    product_photos = Enum.reject(socket.assigns.product_photos, fn p -> p == photo end)

    uploaded_files = Enum.reject(socket.assigns.uploaded_files, fn p -> p == photo end)

    socket =
      if socket.assigns.form[:featured_photo].value == photo do
        remaining_photos = product_photos ++ uploaded_files

        form =
          if Enum.empty?(remaining_photos) do
            AshPhoenix.Form.validate(socket.assigns.form, %{"featured_photo" => nil})
          else
            AshPhoenix.Form.validate(socket.assigns.form, %{
              "featured_photo" => List.first(remaining_photos)
            })
          end

        assign(socket, form: form)
      else
        socket
      end

    {:noreply,
     assign(socket,
       product_photos: product_photos,
       uploaded_files: uploaded_files,
       removed_photos: removed_photos
     )}
  end

  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        dbg(entry)
        path_with_extension = path <> String.replace(entry.client_type, "image/", ".")
        File.cp!(path, path_with_extension)

        Photo.store({path_with_extension, socket.assigns.product})
      end)

    all_photos =
      Enum.reject(socket.assigns.product_photos ++ uploaded_files, fn photo ->
        photo in socket.assigns.removed_photos
      end)

    product_params = Map.put(%{}, "photos", all_photos)

    product_params =
      if (is_nil(socket.assigns.form[:featured_photo].value) ||
            socket.assigns.form[:featured_photo].value in socket.assigns.removed_photos) &&
           length(all_photos) > 0 do
        Map.put(product_params, "featured_photo", List.first(all_photos))
      else
        Map.put(product_params, "featured_photo", socket.assigns.form[:featured_photo].value)
      end

    case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        Enum.each(socket.assigns.removed_photos, fn photo ->
          Photo.delete({photo, socket.assigns.product})
        end)

        {:noreply,
         put_flash(
           socket,
           :info,
           "Product photos #{socket.assigns.form.source.type}d successfully"
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{product: product}} = socket) do
    product = Ash.load!(product, recipe: [:components])

    form =
      AshPhoenix.Form.for_update(product, :update,
        as: "product",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
