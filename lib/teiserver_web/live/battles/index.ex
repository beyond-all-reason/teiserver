defmodule TeiserverWeb.Battle.LobbyLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Account}
  alias Teiserver.Battle.{Lobby, LobbyLib}

  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> TSAuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    client = Account.get_client_by_id(socket.assigns[:current_user].id)

    lobbies = Lobby.list_lobbies()
      |> Enum.map(fn lobby ->
        Map.merge(lobby, %{
          member_count: Battle.get_lobby_member_count(lobby.id) || 0,
          player_count: Battle.get_lobby_player_count(lobby.id) || 0,
          uuid: Battle.get_lobby_match_uuid(lobby.id)
        })
      end)
      |> sort_lobbies

    socket = socket
      # |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/teiserver/battle/lobbies")
      |> assign(:client, client)
      |> assign(:site_menu_active, "lobbies")
      |> assign(:view_colour, LobbyLib.colours())
      |> assign(:lobbies, lobbies)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))

    {:ok, socket, layout: {CentralWeb.LayoutView, :standard_live}}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(%{
    channel: "teiserver_global_lobby_updates",
    event: :opened,
    lobby: lobby
  }, socket) do
    lobbies = [lobby | socket.assigns[:lobbies]]
      |> sort_lobbies

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(%{
    channel: "teiserver_global_lobby_updates",
    event: :closed,
    lobby_id: lobby_id
  }, socket) do
    lobbies =
      socket.assigns[:lobbies]
      |> Enum.filter(fn b -> b.id != lobby_id end)
      |> sort_lobbies

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(%{
    channel: "teiserver_global_lobby_updates",
    event: :updated_values,
    lobby_id: lobby_id,
    new_values: new_values
  }, socket) do
    lobbies =
      socket.assigns[:lobbies]
      |> Enum.map(fn l ->
        if l.id == lobby_id do
          Map.merge(l, new_values)
        else
          l
        end
      end)
      |> sort_lobbies

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  # Client action
  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    {:noreply,
      socket
        |> assign(:client, Account.get_client_by_id(socket.assigns[:current_user].id))
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply,
      socket
        |> assign(:client, nil)
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", _, %{assigns: %{client: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join", %{"lobby_id" => lobby_id}, %{assigns: assigns} = socket) do
    lobby_id = int_parse(lobby_id)

    if Battle.server_allows_join?(assigns.client.userid, lobby_id) == true do
      Battle.add_user_to_lobby(assigns.current_user.id, lobby_id, Teiserver.Battle.Lobby.new_script_password())
    end

    {:noreply, socket}
  end

  defp sort_lobbies(lobbies) do
    lobbies
      |> Enum.sort_by(
        fn v -> {v.locked, v.password != nil, -v.member_count, v.name} end,
        &<=/2
      )
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_global_lobby_updates")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{socket.assigns[:current_user].id}")

    socket
      |> assign(:page_title, "Listing Battles")
      |> assign(:battle, nil)
  end
end
