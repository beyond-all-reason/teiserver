defmodule TeiserverWeb.AdminDashLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Coordinator, Game}
  alias Teiserver.Account.AccoladeLib

  @empty_telemetry_data %{
    client: %{
      total: 0,
      player: 0,
      spectator: 0
    },
    battle: %{
      total: 0,
      in_progress: 0
    },
    total_clients_connected: 0
  }

  @impl true
  def mount(_params, session, socket) do
    telemetry_data =
      Teiserver.cache_get(:application_temp_cache, :telemetry_data) || @empty_telemetry_data

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/admin/dashboard")
      |> assign(:site_menu_active, "admin")
      |> assign(:view_colour, Teiserver.Admin.AdminLib.colours())
      |> assign(:telemetry_client, telemetry_data.client)
      |> assign(:telemetry_battle, telemetry_data.battle)
      |> assign(:total_connected_clients, telemetry_data.total_clients_connected)
      |> update_policies
      |> update_lobbies
      |> update_server_pids

    :timer.send_interval(5_000, :tick)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Moderator") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply,
     socket
     |> update_policies
     |> update_lobbies
     |> update_server_pids}
  end

  def handle_info(%{channel: "teiserver_telemetry", data: data}, socket) do
    {:noreply,
     socket
     |> assign(:telemetry_loading, false)
     |> assign(:telemetry_client, data.client)
     |> assign(:telemetry_battle, data.battle)
     |> assign(:total_connected_clients, data.total_clients_connected)}
  end

  @impl true
  def handle_event("check-consuls", _event, socket) do
    Coordinator.start_all_consuls()
    {:noreply, socket}
  end

  def handle_event("reinit-consuls", _event, socket) do
    Battle.list_lobby_ids()
    |> Enum.each(fn lobby_id ->
      Coordinator.cast_consul(lobby_id, :reinit)
    end)

    {:noreply, socket}
  end

  def handle_event("check-balances", _event, socket) do
    Coordinator.start_all_balancers()
    {:noreply, socket}
  end

  def handle_event("reinit-balances", _event, socket) do
    Battle.list_lobby_ids()
    |> Enum.each(fn lobby_id ->
      Coordinator.cast_balancer(lobby_id, :reinit)
    end)

    {:noreply, socket}
  end

  def handle_event("restart-policies", _event, socket) do
    Game.pre_cache_policies()
    {:noreply, socket}
  end

  @spec update_policies(Plug.Socket.t()) :: Plug.Socket.t()
  defp update_policies(socket) do
    policies =
      Game.list_lobby_policies()
      |> Enum.map(fn lobby_policy ->
        organiser_pid = Game.get_lobby_organiser_pid(lobby_policy.id)
        {lobby_policy, organiser_pid}
      end)
      |> Enum.sort_by(fn t -> elem(t, 0).name end, &<=/2)

    socket
    |> assign(:policies, policies)
  end

  @spec update_lobbies(Plug.Socket.t()) :: Plug.Socket.t()
  defp update_lobbies(socket) do
    lobbies =
      Battle.list_lobby_ids()
      |> Enum.map(fn lobby_id ->
        consul_pid = Coordinator.get_consul_pid(lobby_id)
        balancer_pid = Coordinator.get_balancer_pid(lobby_id)

        throttle_pid =
          case Horde.Registry.lookup(Teiserver.ThrottleRegistry, "LobbyThrottle:#{lobby_id}") do
            [{pid, _}] -> pid
            _ -> nil
          end

        {lobby_id, consul_pid, balancer_pid, throttle_pid}
      end)
      |> Enum.map(fn {lobby_id, consul_pid, balancer_pid, throttle_pid} ->
        {Battle.get_lobby(lobby_id), consul_pid, balancer_pid, throttle_pid}
      end)
      |> Enum.sort_by(fn t -> elem(t, 0).name end, &<=/2)

    socket
    |> assign(:lobbies, lobbies)
  end

  @spec update_server_pids(Plug.Socket.t()) :: Plug.Socket.t()
  defp update_server_pids(socket) do
    lobby_id_server_pid =
      case Horde.Registry.lookup(Teiserver.ServerRegistry, "LobbyIdServer") do
        [{pid, _}] -> pid
        _ -> nil
      end

    server_pids = [
      {"Lobby ID server", lobby_id_server_pid},
      {"Coordinator", Coordinator.get_coordinator_pid()},
      {"Accolades", AccoladeLib.get_accolade_bot_pid()},
      {"Match Monitor", Teiserver.Battle.MatchMonitorServer.get_match_monitor_pid()},
      {"Automod", Teiserver.Coordinator.AutomodServer.get_automod_pid()}
    ]

    socket
    |> assign(:server_pids, server_pids)
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_telemetry")

    socket
    |> assign(:page_title, "Admin dashboard")
    |> assign(:client, nil)
  end
end
