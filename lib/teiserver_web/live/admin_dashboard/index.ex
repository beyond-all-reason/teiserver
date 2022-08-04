defmodule TeiserverWeb.AdminDashLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Coordinator}
  alias Teiserver.Account.AccoladeLib

  @impl true
  def mount(_params, session, socket) do
    socket = socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/teiserver/admin/dashboard")
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:view_colour, Central.Admin.AdminLib.colours())
      |> assign(:telemetry_loading, true)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> update_lobbies
      |> update_server_pids

    :timer.send_interval(5_000, :tick)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
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
      _ ->nil
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
    |> assign(:page_title, "Listing Clients")
    |> assign(:client, nil)
  end
end
