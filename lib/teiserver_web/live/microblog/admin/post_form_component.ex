defmodule TeiserverWeb.Microblog.PostFormComponent do
  use CentralWeb, :live_component

  alias Teiserver.Microblog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage post records in your database.</:subtitle>
      </.header>

      <.form for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <label for="post_title" class="control-label">Title</label>
        <.input field={@form[:title]} type="text" autofocus="autofocus" />
        <br />

        <label for="post_tags" class="control-label">Tags</label>
        <.input type="select"
          name="tags"
          value={}
          options={@tags}
        />
        <br />

        <label for="post_contents" class="control-label">Contents</label>
        <textarea name="post[contents]" id="post_contents" rows="3" class="form-control"></textarea>
        <br />

        <%!-- <.input field={@form[:contents]} type="textarea" /> --%>

        <%= submit("Post", class: "btn btn-primary btn-block") %>
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
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.post
      |> Microblog.change_post(post_params)
      |> Map.put(:action, :validate)

    notify_parent({:updated_changeset, changeset})

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    case Microblog.update_post(socket.assigns.post, post_params) do
      {:ok, post} ->
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

    case Microblog.create_post(post_params) do
      {:ok, post} ->
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
