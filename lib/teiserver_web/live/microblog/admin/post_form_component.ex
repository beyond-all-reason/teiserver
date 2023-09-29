defmodule TeiserverWeb.Microblog.PostFormComponent do
  use CentralWeb, :live_component

  alias Teiserver.Microblog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
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
            <label for="post_title" class="control-label">Title</label>
            <.input
              field={@form[:title]}
              type="text"
              autofocus="autofocus"
              phx-debounce="100"
            />
          </div>
          <div class="col">
            <label for="post_tags" class="control-label">Tags</label>
            <.input type="select"
              name="post[tags][]"
              value={@selected_tags}
              multiple={true}
              options={@tags}
            />
          </div>
        </div>
        <div class="row mb-4">
          <div class="col">
            <label for="post_contents" class="control-label">Contents</label>
            <textarea
              name="post[contents]"
              id="post_contents"
              rows="5"
              phx-debounce="100"
              class="form-control"><%= @form[:contents].value %></textarea>
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
    |> Enum.map(fn tag ->
      {tag.name, tag.id}
    end)

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
      |> assign(:selected_tags, post_params["tags"] || [])
    }
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    tag_ids = post_params["tags"]
      |> Enum.map(fn tag_id_str -> String.to_integer(tag_id_str) end)

    case Microblog.update_post(socket.assigns.post, post_params) do
      {:ok, post} ->
        post_tags = tag_ids
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
         |> put_flash(:info, "Forum updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    post_params = Map.merge(post_params, %{
      "poster_id" => socket.assigns.current_user.id
    })

    tag_ids = post_params["tags"]
      |> Enum.map(fn tag_id_str -> String.to_integer(tag_id_str) end)

    case Microblog.create_post(post_params) do
      {:ok, post} ->
        post_tags = tag_ids
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
         |> put_flash(:info, "Forum created successfully")
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
