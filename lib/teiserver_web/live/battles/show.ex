defmodule TeiserverWeb.Battle.LobbyLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.{Client, Coordinator, User}
  alias Teiserver.Battle.{Lobby, LobbyLib}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/admin/client' class="btn btn-outline-primary">
      <i class="fa-solid fa-fw fa-plug"></i>
      Clients
    </a>
  """

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    extra_content = if allow?(socket, "teiserver.moderator.account") do
      @extra_menu_content
    end

    socket = socket
      |> Teiserver.ServerUserPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/teiserver/battle/lobbies")
      |> assign(:site_menu_active, "teiserver_match")
      |> assign(:view_colour, LobbyLib.colours())
      |> assign(:messages, [])
      |> assign(:extra_menu_content, extra_content)
      |> assign(:consul_command, "")
      |> assign(:subbed, true)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_liveview_lobby_updates:#{id}")
    battle = Lobby.get_battle!(id)

    case battle do
      nil ->
        index_redirect(socket)

      _ ->
        {users, clients} = get_user_and_clients(battle.players)

        bar_user = User.get_user_by_id(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:bar_user, bar_user)
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> add_breadcrumb(name: battle.name, url: "/teiserver/battles/lobbies/#{battle.id}")
         |> assign(:id, int_parse(id))
         |> assign(:battle, battle)
         |> get_consul_state
         |> assign(:users, users)
         |> assign(:clients, clients)}
    end
  end

  defp get_user_and_clients(id_list) do
    users =
      User.list_users(id_list)
      |> Map.new(fn u -> {u.id, u} end)

    clients =
      Client.get_clients(id_list)
      |> Map.new(fn c -> {c.userid, c} end)

    {users, clients}
  end

  # defp add_user(%{assigns: assigns} = socket, id) do
  #   id = int_parse(id)
  #   client = Client.get_client_by_id(id)

  #   if client do
  #     new_users = Map.put(assigns.users, id, User.get_user_by_id(id))
  #     new_clients = Map.put(assigns.clients, id, client)

  #     socket
  #     |> assign(:users, new_users)
  #     |> assign(:clients, new_clients)
  #     |> assign(:battle, Lobby.get_battle(assigns.id))
  #     |> get_consul_state
  #     |> maybe_index_redirect
  #   else
  #     socket
  #   end
  # end

  # defp remove_user(%{assigns: assigns} = socket, id) do
  #   id = int_parse(id)
  #   new_users = Map.delete(assigns.users, id)
  #   new_clients = Map.delete(assigns.clients, id)

  #   socket
  #   |> assign(:users, new_users)
  #   |> assign(:clients, new_clients)
  #   |> assign(:battle, Lobby.get_battle(assigns.id))
  #   |> get_consul_state
  #   |> maybe_index_redirect
  # end

  @impl true
  def handle_info({:battle_lobby_throttle, :closed}, socket) do
    {:noreply,
      socket
      |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end

   def handle_info({:liveview_lobby_update, :consul_server_updated, _, _}, socket) do
    socket = socket
      |> get_consul_state

    {:noreply, socket}
  end

  def handle_info({:battle_lobby_throttle, _lobby_changes, player_changes}, %{assigns: assigns} = socket) do
    battle = Lobby.get_battle(assigns.id)

    socket = socket
      |> assign(:battle, battle)
      |> get_consul_state

    # Players
    # TODO: This can likely be optimised somewhat
    socket = case player_changes do
      [] ->
        socket
      _ ->
        players = Lobby.get_lobby_players!(assigns.id)
        {users, clients} = get_user_and_clients(players)

        socket
          |> assign(:users, users)
          |> assign(:clients, clients)

    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send-to-host", %{"msg" => msg}, %{assigns: assigns} = socket) do
    from_id = Coordinator.get_coordinator_userid()
    Coordinator.handle_in(from_id, msg, assigns.id)

    {:noreply, socket}
  end

  def handle_event("force-update", _, %{assigns: %{id: id}} = socket) do
    battle = Lobby.get_battle(id)
    {users, clients} = get_user_and_clients(battle.players)

    {:noreply,
      socket
      |> assign(:battle, battle)
      |> get_consul_state
      |> assign(:users, users)
      |> assign(:clients, clients)}
  end

  def handle_event("reset-consul", _event, %{assigns: %{id: id, bar_user: bar_user}} = socket) do
    Coordinator.cast_consul(id, %{
      command: "reset",
      senderid: bar_user.id,
      vote: false,
      silent: true
    })
    {:noreply, socket}
  end

  def handle_event("forcespec:" <> target_id, _event, %{assigns: %{id: id, bar_user: bar_user}} = socket) do
    # Lobby.force_change_client(bar_user.id, int_parse(target_id), :player, false)
    Coordinator.cast_consul(id, %{
      command: "forcespec",
      remaining: int_parse(target_id),
      senderid: bar_user.id,
      vote: false,
      silent: true
    })
    {:noreply, socket}
  end

  def handle_event("kick:" <> target_id, _event, %{assigns: %{id: id, bar_user: _bar_user}} = socket) do
    Lobby.kick_user_from_battle(int_parse(target_id), id)
    {:noreply, socket}
  end

  def handle_event("ban:" <> target_id, _event, %{assigns: %{id: id, bar_user: bar_user}} = socket) do
    Coordinator.cast_consul(id, %{
      command: "lobbyban",
      remaining: int_parse(target_id),
      senderid: bar_user.id,
      vote: false,
      silent: true
    })
    {:noreply, socket}
  end

  defp get_consul_state(%{assigns: %{id: id}} = socket) do
    socket
    |> assign(:consul, Coordinator.call_consul(id, :get_all))
  end

  defp page_title(:show), do: "Show Battle"
  defp index_redirect(socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end
end
