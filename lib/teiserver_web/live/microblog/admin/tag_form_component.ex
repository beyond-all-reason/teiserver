defmodule TeiserverWeb.Microblog.TagFormComponent do
  use CentralWeb, :live_component

  alias Teiserver.Microblog

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage tag records in your database.</:subtitle>
      </.header>

      <.form for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="row mb-4">
          <div class="col">
            <label for="tag_name" class="control-label">Name</label>
            <.input
              field={@form[:name]}
              type="text"
              autofocus="autofocus"
              phx-debounce="100"
            />
          </div>
        </div>
        <div class="row mb-4">
          <div class="col">
            <label for="tag_colour" class="control-label">Colour</label>
            <.input
              field={@form[:colour]}
              type="color"
              phx-debounce="100"
            />
          </div>
        </div>
        <div class="row mb-4">
          <div class="col">
            <label for="tag_icon" class="control-label">Icon</label>
            <.input
              field={@form[:icon]}
              type="text"
              phx-debounce="100"
            />
          </div>
        </div>

        <% disabled = if not @form.source.valid?, do: "disabled" %>
        <%= submit("Created tag", class: "btn btn-primary btn-block #{disabled}") %>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{tag: tag} = assigns, socket) do
    changeset = Microblog.change_tag(tag)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"tag" => tag_params}, socket) do
    tag_params = Map.merge(tag_params, %{
      "tager_id" => socket.assigns.current_user.id
    })

    changeset =
      socket.assigns.tag
      |> Microblog.change_tag(tag_params)
      |> Map.put(:action, :validate)

    notify_parent({:updated_changeset, changeset})

    {:noreply, socket
      |> assign_form(changeset)
    }
  end

  def handle_event("save", %{"tag" => tag_params}, socket) do
    save_tag(socket, socket.assigns.action, tag_params)
  end

  defp save_tag(socket, :edit, tag_params) do
    case Microblog.update_tag(socket.assigns.tag, tag_params) do
      {:ok, tag} ->
        notify_parent({:saved, tag})

        {:noreply,
         socket
         |> put_flash(:info, "Forum updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_tag(socket, :new, tag_params) do
    tag_params = Map.merge(tag_params, %{
      "tager_id" => socket.assigns.current_user.id
    })

    case Microblog.create_tag(tag_params) do
      {:ok, tag} ->
        notify_parent({:saved, tag})

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
