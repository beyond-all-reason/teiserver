defmodule TeiserverWeb.AdminDashLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Coordinator, Game}
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Data.Matchmaking

  @impl true
  def mount(_params, session, socket) do
    telemetry_data = Central.cache_get(:application_temp_cache, :telemetry_data)

    socket = socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/admin/dashboard")
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:view_colour, Central.Admin.AdminLib.colours())
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:telemetry_client, telemetry_data.client)
      |> assign(:telemetry_battle, telemetry_data.battle)
      |> update_queues
      |> update_policies
      |> update_lobbies
      |> update_server_pids

    :timer.send_interval(5_000, :tick)

    {:ok, socket, layout: {CentralWeb.LayoutView, :standard_live}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.staff.moderator") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply,
      socket
        |> update_queues
        |> update_policies
        |> update_lobbies
        |> update_server_pids
    }
  end

  def handle_info(%{channel: "teiserver_telemetry", data: data}, socket) do
    {:noreply,
      socket
        |> assign(:telemetry_loading, false)
        |> assign(:telemetry_client, data.client)
        |> assign(:telemetry_battle, data.battle)
    }
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

  @spec update_queues(Plug.Socket.t()) :: Plug.Socket.t()
  defp update_queues(socket) do
    queues = Matchmaking.list_queues()
      |> Enum.map(fn queue ->
        wait_pid = Matchmaking.get_queue_wait_pid(queue.id)
        {queue, wait_pid}
      end)
      |> Enum.sort_by(fn t -> elem(t, 0).name end, &<=/2)

    socket
      |> assign(:queues, queues)
  end

  @spec update_policies(Plug.Socket.t()) :: Plug.Socket.t()
  defp update_policies(socket) do
    policies = Game.list_lobby_policies()
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
    lobbies = Battle.list_lobby_ids()
      |> Enum.map(fn lobby_id ->
        consul_pid = Coordinator.get_consul_pid(lobby_id)
        balancer_pid = Coordinator.get_balancer_pid(lobby_id)
        throttle_pid = case Horde.Registry.lookup(Teiserver.ServerRegistry, "LobbyThrottle:#{lobby_id}") do
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
    lobby_id_server_pid = case Horde.Registry.lookup(Teiserver.ServerRegistry, "LobbyIdServer") do
      [{pid, _}] -> pid
      _ -> nil
    end

    server_pids = [
      {"Lobby ID server", lobby_id_server_pid},
      {"Coordinator", Coordinator.get_coordinator_pid()},
      {"Accolades", AccoladeLib.get_accolade_bot_pid()},
    ]

    socket
      |> assign(:server_pids, server_pids)
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_telemetry")

    socket
    |> assign(:page_title, "Admin dashboard")
    |> assign(:client, nil)
  end
end
