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
            <div :if={@upload_warning} class="mb-4 rounded-md bg-yellow-50 p-4">
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
        accept: ~w(.jpg .jpeg .png),
        max_entries: 10,
        max_file_size: 10_000_000,
        progress: &handle_progress/3
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
        # notify_parent({:saved, product})

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

  def handle_progress(:photos, entry, socket) do
    if entry.done? do
      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          case validate_image_dimensions(entry.client_type, path) do
            :ok ->
              {:ok, path}

            {:error, message} ->
              {:postpone, {:error, message}}
          end
        end)

      dbg(result)

      case result do
        {:error, message} ->
          socket =
            socket
            |> cancel_upload(:photos, entry.ref)
            |> assign(:upload_warning, message)

          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp validate_image_dimensions(_content_type, path) do
    {_, width, height, _} =
      path
      |> File.read!()
      |> ExImageInfo.info()

    if width == height do
      :ok
    else
      {:error, "Image must be square (width and height must be equal)"}
    end
  end

  defp _notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
