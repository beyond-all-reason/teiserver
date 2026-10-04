defmodule TeiserverWeb.AdminLive.DiscordChannel.Show do
  @moduledoc false
  alias Teiserver.Communication
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.DiscordChannel.FormComponent
  alias TeiserverWeb.AdminLive.DiscordChannelComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:discord_channel, Communication.get_discord_channel!(id))
    |> noreply()
  end

  defp page_title(:show), do: "Show Discord channel"
  defp page_title(:edit), do: "Edit Discord channel"

  @impl LiveView
  def handle_event("delete-discord-channel", %{}, %Socket{assigns: assigns} = socket) do
    %{discord_channel: discord_channel, scope: scope} = assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, _discord_channel} <-
               Communication.delete_discord_channel(assigns.discord_channel),
             %{} <-
               add_audit_log(scope, "Delete DiscordChannel", %{
                 discord_channel_id: discord_channel.id
               }) do
          {:ok, :success}
        else
          _error -> {:error, :error}
        end
      end)

    case result do
      {:ok, :success} ->
        socket
        |> redirect(to: ~p"/admin/discord_channels")
        |> put_flash(:success, "Discord channel deleted")
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to delete discord channel")
        |> noreply()
    end
  end
end
