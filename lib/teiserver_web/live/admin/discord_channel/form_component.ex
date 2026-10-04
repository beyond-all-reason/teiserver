defmodule TeiserverWeb.AdminLive.DiscordChannel.FormComponent do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Communication
  alias Teiserver.Communication.DiscordChannel

  use TeiserverWeb, :live_component

  attr :title, :string, required: true
  attr :action, :string, required: true
  attr :discord_channel, DiscordChannel, required: true
  attr :patch, :string, required: true
  attr :scope, Scope, required: true

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

      <.simple_form
        for={@form}
        id="discord_channel-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:name]} type="text" label="Name" />

        <.input_tw field={@form[:channel_id]} type="text" label="Channel ID" />

        <:actions>
          <div class="flex">
            <.button
              phx-disable-with="Saving..."
              class={["float-right btn btn-primary", not @changed? && "btn-soft"]}
            >
              Save Discord channel
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{discord_channel: discord_channel} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(Communication.change_discord_channel(discord_channel))
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("validate", %{"discord_channel" => discord_channel_params}, socket) do
    changeset =
      Communication.change_discord_channel(socket.assigns.discord_channel, discord_channel_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"discord_channel" => discord_channel_params}, socket) do
    save_discord_channel(socket, socket.assigns.action, discord_channel_params)
  end

  defp save_discord_channel(socket, :edit, discord_channel_params) do
    %{discord_channel: discord_channel, scope: scope, patch: patch} = socket.assigns
    changeset = Communication.change_discord_channel(discord_channel, discord_channel_params)

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, updated_discord_channel} <- Repo.update(changeset),
             %{} <-
               add_audit_log(scope, "Update DiscordChannel", %{
                 discord_channel_id: discord_channel.id,
                 changes: changeset.changes
               }) do
          {:ok, updated_discord_channel}
        end
      end)

    case result do
      {:ok, updated_discord_channel} ->
        notify_parent({:saved, updated_discord_channel})

        socket
        |> put_flash(:info, "Discord channel updated successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_discord_channel(socket, :new, discord_channel_params) do
    %{scope: scope, patch: patch} = socket.assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, discord_channel} <-
               Communication.create_discord_channel(discord_channel_params),
             %{} <-
               add_audit_log(scope, "Create DiscordChannel", %{
                 discord_channel_id: discord_channel.id,
                 params: discord_channel_params
               }) do
          {:ok, discord_channel}
        end
      end)

    case result do
      {:ok, discord_channel} ->
        notify_parent({:saved, discord_channel})

        socket
        |> put_flash(:info, "Discord channel created successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
