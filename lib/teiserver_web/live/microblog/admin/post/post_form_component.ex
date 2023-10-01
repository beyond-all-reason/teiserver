defmodule TeiserverWeb.Microblog.PostFormComponent do
  @moduledoc false
  use CentralWeb, :live_component
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 2]

  alias Teiserver.Microblog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <style type="text/css">
        .tag-selector {
          cursor: pointer;
          border: 1px solid #FFF;
          font-size: 1em;
        }
      </style>

      <h3>
        <%= @title %>
      </h3>

      <.form for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="row mb-4">
          <div class="col">
            <label for="post_title" class="control-label">Title:</label>
            <.input
              field={@form[:title]}
              type="text"
              autofocus="autofocus"
              phx-debounce="100"
            />
            <br />

            <label for="post_contents" class="control-label">Contents:</label>
            &nbsp;
            <em>Markdown, use a double-line return to split small version from full version.</em>
            <textarea
              name="post[contents]"
              id="post_contents"
              rows="5"
              phx-debounce="100"
              class="form-control"><%= @form[:contents].value %></textarea>
          </div>
          <div class="col">
            <%= for tag <- @tags do %>
              <%= if Enum.member?(@selected_tags, tag.id) do %>
                <span class="badge rounded-pill mx-1 tag-selector" style={"background-color: #{tag.colour}; "} phx-click="toggle-selected-tag" phx-value-tag={tag.id} phx-target={@myself}>
                  <Fontawesome.icon icon={tag.icon} style="solid" />
                  <%= tag.name %>
                </span>
              <% else %>
                <span class="badge rounded-pill mx-1 tag-selector" style={"background-color: #{rgba_css(tag.colour, 0.5)}; border-color: rgba(0,0,0,0);"} phx-click="toggle-selected-tag" phx-value-tag={tag.id} phx-target={@myself}>
                  <Fontawesome.icon icon={tag.icon} style="regular" />
                  <%= tag.name %>
                </span>
              <% end %>
            <% end %>
          </div>
        </div>

        <% disabled = if not @form.source.valid? or Enum.empty?(@selected_tags), do: "disabled" %>
        <%= submit("Post", class: "btn btn-primary btn-block #{disabled}") %>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{post: post} = assigns, socket) do
    tags = Microblog.list_tags(
      order_by: [
        "Name (A-Z)"
      ]
    )

    changeset = Microblog.change_post(post)

    {:ok,
     socket
     |> assign(:tags, tags)
     |> assign(:selected_tags, [])
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    post_params = Map.merge(post_params, %{
      "poster_id" => socket.assigns.current_user.id
    })

    changeset =
      socket.assigns.post
      |> Microblog.change_post(post_params)
      |> Map.put(:action, :validate)

    notify_parent({:updated_changeset, changeset})

    {:noreply, socket
      |> assign_form(changeset)
    }
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  def handle_event("toggle-selected-tag", %{"tag" => tag_id_str}, socket) do
    tag_id = String.to_integer(tag_id_str)

    new_selected_tags = if Enum.member?(socket.assigns.selected_tags, tag_id) do
      List.delete(socket.assigns.selected_tags, tag_id)
    else
      [tag_id | socket.assigns.selected_tags] |> Enum.uniq
    end

    {:noreply, socket
      |> assign(:selected_tags, new_selected_tags)
    }
  end

  defp save_post(socket, :edit, post_params) do
    case Microblog.update_post(socket.assigns.post, post_params) do
      {:ok, post} ->
        post_tags = socket.assigns.selected_tags
          |> Enum.map(fn tag_id ->
            %{
              tag_id: tag_id,
              post_id: post.id
            }
          end)

        Ecto.Multi.new()
        |> Ecto.Multi.insert_all(:insert_all, Teiserver.Microblog.PostTag, post_tags)
        |> Teiserver.Repo.transaction()

        notify_parent({:saved, post})

        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    post_params = Map.merge(post_params, %{
      "poster_id" => socket.assigns.current_user.id
    })

    case Microblog.create_post(post_params) do
      {:ok, post} ->
        post_tags = socket.assigns.selected_tags
          |> Enum.map(fn tag_id ->
            %{
              tag_id: tag_id,
              post_id: post.id
            }
          end)

        Ecto.Multi.new()
        |> Ecto.Multi.insert_all(:insert_all, Teiserver.Microblog.PostTag, post_tags)
        |> Teiserver.Repo.transaction()

        notify_parent({:saved, post})

        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
