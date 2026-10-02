defmodule TeiserverWeb.ModerationLive.User.UserNoteFormComponent do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.UserNote

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    permissions =
      ["Admin", "Senior Moderator", "Moderator", "Overwatch"]
      |> Enum.filter(&allow?(assigns.scope, &1))

    assigns =
      assigns
      |> assign(changed?: not Enum.empty?(assigns.form.source.changes), permissions: permissions)

    ~H"""
    <div>
      <.header>
        {@title}
      </.header>
      <.simple_form
        for={@form}
        id="user_note-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:contents]} type="textarea" label="Content" />

        <.input_tw
          field={@form[:permission]}
          type="select"
          label="Permissions required"
          options={@permissions}
        />

        <div class="my-2">
          <.button
            phx-disable-with="Saving..."
            class={["float-right btn btn-primary", not @changed? && "btn-soft"]}
          >
            Save User note
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{user_note: user_note} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(UserNote.changeset(user_note))
     end)}
  end

  @impl LiveComponent
  def handle_event("validate", %{"user_note" => user_note_params}, socket) do
    changeset =
      UserNote.changeset(socket.assigns.user_note, user_note_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user_note" => user_note_params}, socket) do
    save_user_note(socket, socket.assigns.action, user_note_params)
  end

  defp save_user_note(socket, :edit, user_note_params) do
    case Account.update_user_note(socket.assigns.user_note, user_note_params) do
      {:ok, user_note} ->
        notify_parent({:saved, user_note})

        {:noreply,
         socket
         |> put_flash(:info, "User note updated successfully")
         |> push_patch(to: ~p"/moderation/users/#{socket.assigns.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_user_note(socket, :new, user_note_params) do
    user_note_params =
      Map.merge(user_note_params, %{
        "user_id" => socket.assigns.id,
        "creator_id" => socket.assigns.scope.user.id
      })

    case Account.create_user_note(user_note_params) do
      {:ok, user_note} ->
        notify_parent({:saved, user_note})

        {:noreply,
         socket
         |> put_flash(:info, "User note created successfully")
         |> push_patch(to: ~p"/moderation/users/#{socket.assigns.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
