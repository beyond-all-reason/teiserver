defmodule TeiserverWeb.Battle.LobbyLive.TachyonIndex do
  use TeiserverWeb, :live_view

  alias Teiserver.TachyonLobby

  @impl true
  def mount(_params, session, socket) do
    case allow?(socket.assigns[:current_user], "Contributor") do
      true ->
        socket =
          socket
          |> AuthPlug.live_call(session)

        {counter, lobbies} = TachyonLobby.subscribe_updates()
        lobby_list = lobbies |> Map.values() |> Enum.sort_by(& &1.name)

        socket =
          socket
          |> assign(:site_menu_active, "tachyon_lobbies")
          |> assign(:view_colour, Teiserver.Lobby.colours())
          |> assign(:lobbies, lobby_list)
          |> assign(:counter, counter)

        {:ok, socket}

      false ->
        {:ok, socket |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(%{event: :add_lobby, overview: overview, counter: _counter}, socket) do
    lobbies =
      [overview | socket.assigns[:lobbies]] |> Enum.uniq_by(& &1.name) |> Enum.sort_by(& &1.name)

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(%{event: :remove_lobby, lobby_id: _lobby_id, counter: _counter}, socket) do
    # We don't have lobby_id in the view state easily mapped unless we store it.
    # To keep it simple, we just refetch if we lose a lobby, or we can store lobby_ids.
    # For now, fetching full list on remove is easiest.
    lobbies = TachyonLobby.list() |> Map.values() |> Enum.sort_by(& &1.name)
    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(%{event: :update_lobbies, counter: _counter, changes: _changes}, socket) do
    # Same as above, easiest is to refetch
    lobbies = TachyonLobby.list() |> Map.values() |> Enum.sort_by(& &1.name)
    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(%{event: :reset_list, counter: _counter, lobbies: lobbies}, socket) do
    lobby_list = lobbies |> Map.values() |> Enum.sort_by(& &1.name)
    {:noreply, assign(socket, :lobbies, lobby_list)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end
