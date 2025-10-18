defmodule CraftplanWeb.ProductLive.FormComponentPhotos do
  @moduledoc """
  LiveComponent for managing product photos including uploading, featuring, and removing.
  """
  use CraftplanWeb, :live_component

  alias Craftplan.Catalog.Product.Photo

  @max_file_size 10_000_000
  @max_entries 10
  @accepted_types ~w(.jpg .jpeg .png .webp)

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
              <%= if @upload_warning do %>
                <div class="mb-4 rounded bg-yellow-50 p-4">
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
              <% end %>

              <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
                <%= for entry <- @uploads.photos.entries do %>
                  <div class="group relative transition-all duration-200 hover:shadow-md">
                    <div class="overflow-hidden rounded-lg border border-stone-200 bg-white transition-all">
                      <div class="relative">
                        <.live_img_preview
                          entry={entry}
                          class="h-48 w-full object-cover transition-transform duration-200 group-hover:scale-105"
                        />
                        <div class="p-3">
                          <p class="truncate text-xs font-medium">
                            {entry.client_name}
                          </p>
                        </div>
                      </div>

                      <div class="flex items-center justify-between p-3">
                        <div class="flex-1 pr-2">
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
                        <div class="flex-shrink-0">
                          <.button
                            type="button"
                            size={:sm}
                            phx-click="cancel-upload"
                            phx-value-ref={entry.ref}
                            phx-target={@myself}
                            aria-label="Cancel upload"
                          >
                            Cancel
                          </.button>
                        </div>
                      </div>
                    </div>

                    <%= for err <- upload_errors(@uploads.photos, entry) do %>
                      <div class="mt-2 rounded-md bg-red-50 p-2 text-xs font-medium text-red-500">
                        {error_to_string(err)}
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%= for err <- upload_errors(@uploads.photos) do %>
                <div class="mt-2 text-sm text-red-500">
                  {error_to_string(err)}
                </div>
              <% end %>

              <%= if Enum.empty?(@uploads.photos.entries) do %>
                <p class="py-4 text-center text-stone-500">
                  Drop files here or click to upload
                </p>
              <% end %>
            </section>
          </label>

          <%= if not Enum.empty?(@product_photos) or not Enum.empty?(@uploaded_files) do %>
            <div class="mt-6">
              <h4 class="text-md mb-2 font-medium">Current Photos</h4>
              <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
                <%= for photo <- @product_photos ++ @uploaded_files do %>
                  <div class="relative">
                    <div class={[
                      "overflow-hidden rounded border-2",
                      (@form[:featured_photo].value == photo && "border-blue-500") ||
                        "border-stone-200"
                    ]}>
                      <img
                        src={Photo.url({photo, @product}, :thumb, signed: true)}
                        class="h-40 w-full object-cover"
                      />

                      <%= if @form[:featured_photo].value == photo do %>
                        <div class="absolute top-1 right-1">
                          <div class="rounded-full bg-blue-500 p-1">
                            <svg
                              xmlns="http://www.w3.org/2000/svg"
                              class="h-4 w-4 text-white"
                              viewBox="0 0 20 20"
                              fill="currentColor"
                            >
                              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                            </svg>
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <div class="mt-2 flex space-x-2">
                      <.button
                        type="button"
                        size={:sm}
                        disabled={@form[:featured_photo].value == photo}
                        phx-click="set-featured"
                        phx-value-photo={photo}
                        phx-target={@myself}
                      >
                        {if @form[:featured_photo].value == photo,
                          do: "Featured",
                          else: "Set as Featured"}
                      </.button>
                      <.button
                        type="button"
                        size={:sm}
                        variant={:danger}
                        phx-click="remove-photo"
                        phx-value-photo={photo}
                        phx-target={@myself}
                      >
                        Remove
                      </.button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <:actions>
          <.button
            phx-disable-with="Saving..."
            disabled={@has_changes == false}
            class={if @has_changes == false, do: "cursor-not-allowed opacity-50", else: ""}
          >
            Save
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign_defaults()
     |> allow_uploads()}
  end

  @impl true
  def update(%{uploads: uploads} = assigns, socket) when is_map(uploads) do
    socket =
      socket
      |> assign(assigns)
      |> ensure_has_changes()
      |> update_has_changes()

    {:ok, socket}
  end

  @impl true
  def update(%{product: product} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> ensure_has_changes()
      |> assign_product_photos(product)
      |> assign_form()
      |> update_has_changes()

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> ensure_has_changes()
      |> update_has_changes()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, update_has_changes(socket)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photos, ref)
     |> update_has_changes()}
  end

  @impl true
  def handle_event("set-featured", %{"photo" => photo}, socket) do
    {:noreply,
     socket
     |> update_form(%{"featured_photo" => photo})
     |> update_has_changes()}
  end

  @impl true
  def handle_event("remove-photo", %{"photo" => photo}, socket) do
    %{product_photos: product_photos, uploaded_files: uploaded_files} = socket.assigns
    removed_photos = [photo | socket.assigns.removed_photos]

    updated_product_photos = Enum.reject(product_photos, &(&1 == photo))
    updated_uploaded_files = Enum.reject(uploaded_files, &(&1 == photo))
    remaining_photos = updated_product_photos ++ updated_uploaded_files

    socket =
      if socket.assigns.form[:featured_photo].value == photo do
        update_form(socket, %{"featured_photo" => List.first(remaining_photos)})
      else
        socket
      end

    {:noreply,
     socket
     |> assign(
       product_photos: updated_product_photos,
       uploaded_files: updated_uploaded_files,
       removed_photos: removed_photos
     )
     |> update_has_changes()}
  end

  @impl true
  def handle_event("save", _params, socket) do
    if socket.assigns.has_changes == false do
      {:noreply, socket}
    else
      uploaded_files = process_uploaded_files(socket)
      all_photos = get_all_photos(socket, uploaded_files)

      product_params = %{
        "photos" => all_photos,
        "featured_photo" => determine_featured_photo(socket, all_photos)
      }

      case AshPhoenix.Form.submit(socket.assigns.form, params: product_params) do
        {:ok, product} ->
          notify_parent({:saved, product})
          delete_removed_photos(socket)

          {:noreply,
           socket
           |> put_flash(:info, "Product photos #{socket.assigns.form.source.type}d successfully")
           |> reset_state(product)}

        {:error, form} ->
          {:noreply, socket |> assign(form: form) |> update_has_changes()}
      end
    end
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:uploaded_files, [])
    |> assign(:product_photos, [])
    |> assign(:removed_photos, [])
    |> assign(:upload_warning, nil)
    |> assign(:original_featured_photo, nil)
    |> assign(:has_changes, false)
  end

  defp ensure_has_changes(socket) do
    has_changes = socket.assigns[:has_changes] || false
    assign(socket, :has_changes, has_changes)
  end

  defp allow_uploads(socket) do
    allow_upload(socket, :photos,
      accept: @accepted_types,
      max_entries: @max_entries,
      max_file_size: @max_file_size
    )
  end

  defp assign_product_photos(socket, product) do
    if product do
      socket
      |> assign(:product_photos, product.photos || [])
      |> assign(:original_featured_photo, product.featured_photo)
    else
      socket
    end
  end

  defp assign_form(%{assigns: %{product: product}} = socket) when not is_nil(product) do
    product = Ash.load!(product, [recipe: [:components]], actor: socket.assigns.current_user)

    form =
      AshPhoenix.Form.for_update(product, :update,
        as: "product",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp assign_form(socket), do: socket

  defp update_form(socket, params) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    assign(socket, form: form)
  end

  defp update_has_changes(socket) do
    has_uploads = socket.assigns.uploads && not Enum.empty?(socket.assigns.uploads.photos.entries)
    has_removed = not Enum.empty?(socket.assigns.removed_photos)
    has_uploaded = not Enum.empty?(socket.assigns.uploaded_files)

    featured_photo_changed =
      socket.assigns[:form] &&
        socket.assigns[:original_featured_photo] &&
        socket.assigns.form[:featured_photo].value != socket.assigns.original_featured_photo

    has_changes = has_uploads || has_removed || has_uploaded || featured_photo_changed

    assign(socket, :has_changes, has_changes)
  end

  defp process_uploaded_files(socket) do
    consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
      filename = entry.client_name

      ext = Path.extname(filename)

      basename =
        filename
        |> Path.basename(ext)
        |> Slug.slugify()

      random_suffix = 8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

      dir = Path.dirname(path)
      path_with_filename = Path.join(dir, "#{basename}-#{random_suffix}#{ext}")

      File.cp!(path, path_with_filename)

      Photo.store({path_with_filename, socket.assigns.product})
    end)
  end

  defp get_all_photos(socket, uploaded_files) do
    Enum.reject(socket.assigns.product_photos ++ uploaded_files, fn photo ->
      photo in socket.assigns.removed_photos
    end)
  end

  defp determine_featured_photo(socket, all_photos) do
    current_featured = socket.assigns.form[:featured_photo].value

    if (is_nil(current_featured) || current_featured in socket.assigns.removed_photos) &&
         length(all_photos) > 0 do
      List.first(all_photos)
    else
      current_featured
    end
  end

  defp delete_removed_photos(socket) do
    Enum.each(socket.assigns.removed_photos, fn photo ->
      Photo.delete({photo, socket.assigns.product})
    end)
  end

  defp reset_state(socket, product) do
    socket
    |> assign(:has_changes, false)
    |> assign(:removed_photos, [])
    |> assign(:uploaded_files, [])
    |> assign(:original_featured_photo, product.featured_photo)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(_), do: "Unknown error occurred during upload"
end
