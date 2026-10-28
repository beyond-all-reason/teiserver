defmodule TeiserverWeb.ModerationLive.BannedPhrase.FormComponent do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(changed?: not Enum.empty?(assigns.form.source.changes))

    ~H"""
    <div>
      <.header>
        {@title}
      </.header>
      <div class="mb-2 text-sm leading-6 text-base-content/70">
        For phrases of type "raw" you can use comma separated values to match on a selection of phrases.
      </div>

      <.simple_form
        for={@form}
        id="banned_phrase-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:phrase]} type="text" label="Phrase" />
        <.input_tw field={@form[:score_threshold]} type="number" label="Score threshold" />
        <.input_tw field={@form[:type]} type="select" label="Type" options={BannedPhrase.types()} />
        <.input_tw
          field={@form[:use_cases]}
          type="select"
          label="Use cases"
          multiple
          options={BannedPhrase.use_cases()}
        />

        <div class="my-2">
          <.button
            phx-disable-with="Saving..."
            class={["float-right btn btn-primary", not @changed? && "btn-soft"]}
          >
            Save Banned phrase
          </.button>
        </div>
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
