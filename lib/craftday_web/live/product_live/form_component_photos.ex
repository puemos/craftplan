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

          <div class="mb-4">
            <.live_file_input upload={@uploads.photos} />
          </div>

          <section
            phx-drop-target={@uploads.photos.ref}
            class="rounded-md border-2 border-dashed border-gray-300 p-4"
          >
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
              <div :for={entry <- @uploads.photos.entries} class="relative">
                <figure class="overflow-hidden rounded-md bg-gray-100">
                  <.live_img_preview entry={entry} class="h-40 w-full object-cover" />
                  <figcaption class="truncate p-2 text-xs">{entry.client_name}</figcaption>
                </figure>

                <div class="mt-2 flex items-center justify-between">
                  <progress value={entry.progress} max="100" class="mr-2 w-full">
                    {entry.progress}%
                  </progress>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="text-red-500"
                  >
                    &times;
                  </button>
                </div>

                <div
                  :for={err <- upload_errors(@uploads.photos, entry)}
                  class="mt-1 text-xs text-red-500"
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
              class="py-4 text-center text-gray-500"
            >
              Drop files here or click the button above to upload
            </p>
          </section>

          <div :if={not Enum.empty?(@product_photos) or not Enum.empty?(@uploaded_files)} class="mt-6">
            <h4 class="text-md mb-2 font-medium">Current Photos</h4>
            <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
              <div :for={photo <- @product_photos ++ @uploaded_files} class="relative">
                <div class={[
                  "overflow-hidden rounded-md border-2",
                  (@form[:featured_photo].value == photo && "border-blue-500") || "border-gray-200"
                ]}>
                  <img
                    src={Craftday.Catalog.Product.Photo.url({photo, @product}, :thumb)}
                    class="h-40 w-full object-cover"
                  />

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
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 10,
        max_file_size: 10_000_000
      )
      |> assign_form()

    # Extract existing photos if product exists
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
    # Add the photo to removed photos list
    removed_photos = [photo | socket.assigns.removed_photos]

    # Update product_photos by removing the photo
    product_photos = Enum.reject(socket.assigns.product_photos, fn p -> p == photo end)

    # Update uploaded_files by removing the photo
    uploaded_files = Enum.reject(socket.assigns.uploaded_files, fn p -> p == photo end)

    # If the featured photo is being removed, set a new one
    socket =
      if socket.assigns.form[:featured_photo].value == photo do
        # Find the first remaining photo to set as featured, if any
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
    # Consume the uploaded files
    uploaded_files =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        path_with_extension = path <> String.replace(entry.client_type, "image/", ".")
        File.cp!(path, path_with_extension)

        Photo.store({path_with_extension, socket.assigns.product})
      end)

    # Combine existing photos with new uploads, excluding removed photos
    all_photos =
      Enum.reject(socket.assigns.product_photos ++ uploaded_files, fn photo ->
        photo in socket.assigns.removed_photos
      end)

    # Update the product parameters with the photos array
    product_params = Map.put(%{}, "photos", all_photos)

    # If no featured photo is set, but we have photos, set the first as featured
    product_params =
      if (is_nil(socket.assigns.form[:featured_photo].value) ||
            socket.assigns.form[:featured_photo].value in socket.assigns.removed_photos) &&
           length(all_photos) > 0 do
        Map.put(product_params, "featured_photo", List.first(all_photos))
      else
        # Pass the current featured photo value
        Map.put(product_params, "featured_photo", socket.assigns.form[:featured_photo].value)
      end

    case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})
        # Delete removed photos
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
