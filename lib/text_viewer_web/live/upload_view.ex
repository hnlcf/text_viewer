defmodule TextViewerWeb.UploadView do
  require Logger
  use TextViewerWeb, :live_view

  import Phoenix.Component

  # Max file size: 1GB
  @max_file_size 1000_000_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_file, nil)
     |> assign(:content, [])
     |> assign(:current_section, 0)
     |> assign(:state, :upload)
     |> assign(:parse_mode, :split_by_dash)
     |> assign(:parse_modes,
       "Start with equal": :start_with_equal,
       "Split by dash": :split_by_dash
     )
     |> allow_upload(:novel,
       accept: ~w(.txt),
       auto_upload: true,
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_event("validate", %{"mode-selection" => parse_mode} = _params, socket) do
    {:noreply, socket |> assign(:parse_mode, String.to_atom(parse_mode))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :novel, ref)}
  end

  @impl true
  def handle_event("validate-section", %{"index" => _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change-section", %{"index" => index}, socket) do
    {:noreply, assign(socket, :current_section, String.to_integer(index))}
  end

  @impl true
  def handle_event("inc-section", _params, socket) do
    {:noreply, inc_section(socket)}
  end

  @impl true
  def handle_event("dec-section", _params, socket) do
    {:noreply, dec_section(socket)}
  end

  @impl true
  def handle_event("maybe-change-section", %{"key" => key}, socket) do
    case key do
      "ArrowLeft" ->
        {:noreply, dec_section(socket)}

      "ArrowRight" ->
        {:noreply, inc_section(socket)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    with {[_ | _] = entries, []} <- uploaded_entries(socket, :novel) do
      entry = Enum.at(entries, 0)

      uploaded_file =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          upload_path = "priv/static/uploads"

          if !File.exists?(upload_path) do
            File.mkdir!(upload_path)
          end

          dest = Path.join(upload_path, Path.basename(path))
          File.cp!(path, dest)

          {:ok, dest}
        end)

      Task.async(fn ->
        TextViewer.TextReader.read(uploaded_file, socket.assigns.parse_mode)
      end)

      socket =
        socket
        |> assign(uploaded_file: uploaded_file)
        |> assign(state: :parse)

      uploaded_file
      |> IO.inspect()
      |> Logger.debug()

      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({ref, resp}, socket) do
    Process.demonitor(ref, [:flush])

    {
      :noreply,
      socket
      |> assign(:content, resp)
      |> assign(:state, :show)
    }
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

  defp inc_section(socket) do
    max = length(socket.assigns.content) - 1
    index = socket.assigns.current_section

    if index < max do
      assign(socket, :current_section, index + 1)
    else
      socket
    end
  end

  defp dec_section(socket) do
    index = socket.assigns.current_section

    if index > 0 do
      assign(socket, :current_section, index - 1)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @state == :upload do %>
      <div>
        <form id="upload-form" phx-submit="save" phx-change="validate">
          <.live_file_input upload={@uploads.novel} />
          <.input
            name="mode-selection"
            type="select"
            field={@parse_mode}
            options={@parse_modes}
            value={:split_by_dash}
          />
          <.button type="submit">上传</.button>
        </form>

        <section phx-drop-target={@uploads.novel.ref}>
          <%= for entry <- @uploads.novel.entries do %>
            <article class="upload-entry">
              <p><%= entry.client_name %></p>

              <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>

              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                aria-label="cancel"
              >
                &times;
              </button>

              <%= for err <- upload_errors(@uploads.novel, entry) do %>
                <p class="alert alert-danger"><%= error_to_string(err) %></p>
              <% end %>
            </article>
          <% end %>

          <%= for err <- upload_errors(@uploads.novel) do %>
            <p class="alert alert-danger"><%= error_to_string(err) %></p>
          <% end %>
        </section>
      </div>
    <% else %>
      <div class="">
        <%= if @state == :parse do %>
          <p class="text-xl font-bold">正在解析上传文件 ...</p>
        <% else %>
          <div
            phx-window-keydown="maybe-change-section"
            class="flex h-screen w-screen p-2 cursor-auto justify-center"
          >
            <%!-- TOC --%>
            <div id="toc-bar" class="w-1/5 bg-white shadow-xl rounded overflow-auto">
              <%!-- Jump form --%>
              <form
                id="jump-section"
                phx-submit="change-section"
                phx-change="validate-section"
                class="mx-4 p-2"
              >
                <p class="text-center text-xl font-bold font-serif">跳转至指定章节</p>
                <.input type="search" name="index" value={@current_section} />
              </form>

              <%!-- Section list --%>
              <div
                id="section-list"
                phx-hook="ScrollToSection"
                data-section={@current_section}
                class="grid grid-col-1 p-4 select-none"
              >
                <%= for {%{id: _, title: title, lines: _}, index} <- Enum.with_index(@content) do %>
                  <%= if index == @current_section do %>
                    <div
                      id={"section-tab-#{index}"}
                      phx-click="change-section"
                      phx-value-index={index}
                      class="text-left text-xl font-bold font-serif mx-4 p-2 bg-gray-200"
                    >
                      <%= index %> -- <%= title %>
                    </div>
                  <% else %>
                    <div
                      id={"section-tab-#{index}"}
                      phx-click="change-section"
                      phx-value-index={index}
                      class="text-left text-xl font-serif mx-4 p-2 hover:bg-gray-200"
                    >
                      <%= index %> -- <%= title %>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <%!-- Main content --%>
            <div id="section" class="w-4/5 flex flex-col grid grid-cols-5">
              <div
                id="section-content"
                phx-hook="ResetScroll"
                class="col-start-2 col-end-4 p-4 bg-gray-100 shadow-xl rounded overflow-scroll select-none"
              >
                <%!-- Jump button --%>
                <div class="flex justify-between">
                  <.button class="m-4" phx-click="dec-section">
                    上一章
                  </.button>
                  <.button class="m-4" phx-click="inc-section">
                    下一章
                  </.button>
                </div>

                <%!-- Section content --%>
                <%= with %{id: id, title: title, lines: lines} <- Enum.at(@content, @current_section) do %>
                  <.live_component
                    id={id}
                    module={TextViewerWeb.LiveComponents.SectionContentComponent}
                    title={title}
                    lines={lines}
                  />
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end
end
