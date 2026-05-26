defmodule TeiserverWeb.Moderation.BannedPhraseLive.FormComponent do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage banned_phrase records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="banned_phrase-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:phrase]} type="text" label="Phrase" />
        <.input field={@form[:score_threshold]} type="number" label="Score threshold" />
        <.input field={@form[:type]} type="select" label="Type" options={BannedPhrase.types()} />
        <.input
          field={@form[:severity]}
          type="select"
          label="Severity"
          options={BannedPhrase.severities()}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Banned phrase</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{banned_phrase: banned_phrase} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Moderation.change_banned_phrase(banned_phrase))
     end)}
  end

  @impl LiveComponent
  def handle_event("validate", %{"banned_phrase" => banned_phrase_params}, socket) do
    changeset =
      Moderation.change_banned_phrase(socket.assigns.banned_phrase, banned_phrase_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"banned_phrase" => banned_phrase_params}, socket) do
    save_banned_phrase(socket, socket.assigns.action, banned_phrase_params)
  end

  defp save_banned_phrase(socket, :edit, banned_phrase_params) do
    case Moderation.update_banned_phrase(socket.assigns.banned_phrase, banned_phrase_params) do
      {:ok, banned_phrase} ->
        notify_parent({:saved, banned_phrase})

        {:noreply,
         socket
         |> put_flash(:info, "Banned phrase updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_banned_phrase(socket, :new, banned_phrase_params) do
    case Moderation.create_banned_phrase(banned_phrase_params) do
      {:ok, banned_phrase} ->
        notify_parent({:saved, banned_phrase})

        {:noreply,
         socket
         |> put_flash(:info, "Banned phrase created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
