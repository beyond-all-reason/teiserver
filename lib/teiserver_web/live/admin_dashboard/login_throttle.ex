defmodule TeiserverWeb.AdminDashLive.LoginThrottle do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  alias Teiserver
  alias Teiserver.{Game}
  # alias Teiserver.Account.AccoladeLib
  # alias Teiserver.Data.Matchmaking

  @impl true
  def mount(_params, session, socket) do
    :ok = PubSub.subscribe(Central.PubSub, "login_throttle_updates")

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/admin/dashboard")
      |> add_breadcrumb(name: "Login throttle", url: "/admin/dashboard/login_throttle")
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:view_colour, Central.Admin.AdminLib.colours())
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))

    :timer.send_interval(5_000, :tick)

    {:ok, socket, layout: {CentralWeb.LayoutView, :standard_live}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.staff.server") do
      true ->
        {:noreply, socket}

      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    {
      :noreply,
      socket
    }
  end

  def handle_info(%{channel: "lobby_policy_updates:" <> _, event: :agent_status} = msg, state) do
    {:noreply,
     state
     |> assign(:bots, msg.agent_status)}
  end

  @impl true
  def handle_event("disconnect-all-bots", _event, socket) do
    Game.cast_lobby_organiser(socket.assigns.id, :disconnect_all_bots)

    {:noreply, socket}
  end

  @spec get_policy_bots(Plug.Socket.t()) :: Plug.Socket.t()
  defp get_policy_bots(socket) do
    bots = Game.call_lobby_organiser(socket.assigns.id, :get_agent_status)

    socket
    |> assign(:bots, bots)
  end
end
