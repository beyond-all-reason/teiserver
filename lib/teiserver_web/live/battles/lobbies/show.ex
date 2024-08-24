defmodule TeiserverWeb.Battle.LobbyLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.Battle.BalanceLib
  alias Teiserver.{Account, Battle, Coordinator, Lobby, CacheUser, Telemetry}
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

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

    moderator = allow?(socket, "Moderator")
    server_perms = allow?(socket, "Server")
    tester_perms = allow?(socket, "Tester")

    extra_content =
      if moderator do
        @extra_menu_content
      end

    client = Account.get_client_by_id(socket.assigns[:current_user].id)
    friends = Account.list_friend_ids_of_user(socket.assigns[:current_user].id)
    ignored = Account.list_userids_ignored_by_userid(socket.assigns[:current_user].id)

    :timer.send_interval(10_000, :tick)

    socket =
      socket
      |> Teiserver.ServerUserPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/battle/lobbies")
      |> assign(:friends, friends)
      |> assign(:ignored, ignored)
      |> assign(:ratings, %{})
      |> assign(:client, client)
      |> assign(:site_menu_active, "teiserver_lobbies")
      |> assign(:view_colour, Lobby.colours())
      |> assign(:messages, [])
      |> assign(:extra_menu_content, extra_content)
      |> assign(:consul_command, "")
      |> assign(:subbed, true)
      |> assign(:moderator, moderator)
      |> assign(:server_perms, server_perms)
      |> assign(:tester_perms, tester_perms)

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: ~p"/")}
  end

  def handle_params(%{"id" => id}, _, %{} = socket) do
    id = int_parse(id)
    current_user = socket.assigns[:current_user]

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_liveview_lobby_updates:#{id}")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_user_updates:#{current_user.id}")
    lobby = Battle.get_lobby(id)

    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{socket.assigns[:current_user].id}"
      )

    cond do
      lobby == nil ->
        index_redirect(socket)

      lobby.tournament ->
        index_redirect(socket)

      (lobby.locked or lobby.passworded) and not allow?(socket, "Moderator") ->
        index_redirect(socket)

      true ->
        {users, clients, ratings, parties, stats} = get_user_and_clients(lobby.players)

        bar_user = CacheUser.get_user_by_id(socket.assigns.current_user.id)
        lobby = Map.put(lobby, :uuid, Battle.get_lobby_match_uuid(id))
        modoptions = Battle.get_modoptions(id)

        {:noreply,
         socket
         |> assign(:ratings, ratings)
         |> assign(:bar_user, bar_user)
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> add_breadcrumb(name: lobby.name, url: "/battles/lobbies/show/#{lobby.id}")
         |> assign(:id, id)
         |> assign(:lobby, lobby)
         |> assign(:modoptions, modoptions)
         |> get_consul_state
         |> assign(:users, users)
         |> assign(:clients, clients)
         |> assign(:stats, stats)
         |> assign(:parties, parties)}
    end
  end

  defp get_user_and_clients(id_list) do
    users =
      CacheUser.list_users(id_list)
      |> Map.new(fn u -> {u.id, u} end)

    clients =
      Account.list_clients(id_list)
      |> Map.new(fn c -> {c.userid, c} end)

    # Creates a map where the party_id refers to an integer
    # but only includes parties with 2 or more members
    parties =
      clients
      |> Enum.map(fn {_, c} -> c end)
      |> Enum.filter(fn c -> c.player end)
      |> Enum.group_by(fn m -> m.party_id end)
      |> Map.drop([nil])
      |> Map.filter(fn {_id, members} -> Enum.count(members) > 1 end)
      |> Map.keys()
      |> Enum.zip(Teiserver.Helper.StylingHelper.bright_hex_colour_list())
      |> Map.new()

    stats =
      users
      |> Map.keys()
      |> Map.new(fn id ->
        {id, Account.get_user_stat_data(id)}
      end)

    ratings =
      users
      |> Map.new(fn {userid, _} ->
        {userid, BalanceLib.get_user_rating_value_uncertainty_pair(userid, "Large Team")}
      end)

    {users, clients, ratings, parties, stats}
  end

  @impl true
  def handle_info(:tick, socket) do
    socket =
      if socket.assigns.lobby.in_progress do
        lobby =
          socket.assigns.id
          |> Battle.get_lobby()
          |> Map.put(:uuid, Battle.get_lobby_match_uuid(socket.assigns.id))

        socket
        |> assign(:lobby, lobby)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:battle_lobby_throttle, :closed}, socket) do
    {:noreply,
     socket
     |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end

  def handle_info({:liveview_lobby_update, :consul_server_updated, _, _}, socket) do
    socket =
      socket
      |> get_consul_state

    {:noreply, socket}
  end

  def handle_info(
        {:battle_lobby_throttle, _lobby_changes, player_changes},
        %{assigns: assigns} = socket
      ) do
    battle = Lobby.get_lobby(assigns.id)
    modoptions = Battle.get_modoptions(assigns.id)

    socket =
      socket
      |> assign(:battle, battle)
      |> assign(:modoptions, modoptions)
      |> get_consul_state

    # Players
    # TODO: This can likely be optimised somewhat
    socket =
      case player_changes do
        [] ->
          socket

        _ ->
          players = Battle.get_lobby_member_list(assigns.id)
          {users, clients, ratings, parties, stats} = get_user_and_clients(players)

          new_lobby = Map.put(assigns[:lobby], :players, players)

          socket
          |> assign(:lobby, new_lobby)
          |> assign(:users, users)
          |> assign(:clients, clients)
          |> assign(:ratings, ratings)
          |> assign(:parties, parties)
          |> assign(:stats, stats)
      end

    {:noreply, socket}
  end

  def handle_info(%{channel: "teiserver_user_updates:" <> _}, %{assigns: %{id: id}} = socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_show_path(socket, :show, id))}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    {:noreply,
     socket
     |> assign(:client, Account.get_client_by_id(socket.assigns[:current_user].id))}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply,
     socket
     |> assign(:client, nil)}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _userid_str}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", _, %{assigns: %{client: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join", _, %{assigns: assigns} = socket) do
    if Battle.server_allows_join?(assigns.client.userid, assigns.id) == true do
      Battle.force_add_user_to_lobby(assigns.current_user.id, assigns.id)
    end

    {:noreply, socket}
  end

  def handle_event("send-to-host", %{"msg" => msg}, %{assigns: assigns} = socket) do
    from_id = Coordinator.get_coordinator_userid()
    Teiserver.Coordinator.Parser.handle_in(from_id, msg, assigns.id)

    {:noreply, socket}
  end

  def handle_event("force-update", _, %{assigns: %{id: id}} = socket) do
    battle = Lobby.get_lobby(id)
    {users, clients, ratings, parties, stats} = get_user_and_clients(battle.players)

    {:noreply,
     socket
     |> assign(:battle, battle)
     |> get_consul_state
     |> assign(:users, users)
     |> assign(:clients, clients)
     |> assign(:ratings, ratings)
     |> assign(:parties, parties)
     |> assign(:stats, stats)}
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

  def handle_event(
        "forcespec:" <> target_id,
        _event,
        %{assigns: %{id: id, bar_user: bar_user}} = socket
      ) do
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

  def handle_event(
        "kick:" <> target_id,
        _event,
        %{assigns: %{id: id, bar_user: _bar_user}} = socket
      ) do
    Lobby.kick_user_from_battle(int_parse(target_id), id)
    Telemetry.log_simple_server_event(int_parse(target_id), "lobby.kicked_from_web_interface")
    {:noreply, socket}
  end

  def handle_event(
        "ban:" <> target_id,
        _event,
        %{assigns: %{id: id, bar_user: bar_user}} = socket
      ) do
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
