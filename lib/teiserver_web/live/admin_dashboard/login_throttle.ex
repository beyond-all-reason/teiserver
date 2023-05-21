defmodule TeiserverWeb.AdminDashLive.LoginThrottle do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Game}
  # alias Teiserver.Account.AccoladeLib
  # alias Teiserver.Data.Matchmaking

  @impl true
  def mount(_params, session, socket) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_liveview_login_throttle")

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Admin", url: ~p"/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: ~p"/admin/dashboard")
      |> add_breadcrumb(name: "Login throttle", url: ~p"/admin/dashboard/login_throttle")
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:view_colour, Central.Admin.AdminLib.colours())
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:heartbeats, %{})
      |> assign(:queues, nil)
      |> assign(:recent_logins, [])
      |> assign(:arrival_times, %{})
      |> assign(:remaining_capacity, 0)
      |> assign(:server_usage, 0)
      |> assign(:awaiting_release, nil)

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

  def handle_info(%{channel: "teiserver_liveview_login_throttle", event: :tick} = msg, state) do
    {:noreply,
     state
      |> assign(:heartbeats, msg.heartbeats)
      |> assign(:queues, msg.queues)
      |> assign(:recent_logins, msg.recent_logins)
      |> assign(:arrival_times, msg.arrival_times)
    }
  end

  def handle_info(%{channel: "teiserver_liveview_login_throttle", event: :add_to_release_list} = msg, %{assigns: assigns} = state) do
    new_heartbeats = Map.drop(assigns.heartbeats, [msg.userid])
    new_arrival_times = Map.drop(assigns.arrival_times, [msg.userid])

    {:noreply,
     state
      |> assign(:heartbeats, new_heartbeats)
      |> assign(:arrival_times, new_arrival_times)
    }
  end

  def handle_info(%{channel: "teiserver_liveview_login_throttle", event: :updated_capacity} = msg, state) do
    {:noreply,
     state
      |> assign(:remaining_capacity, msg.remaining_capacity)
      |> assign(:server_usage, msg.server_usage)
    }
  end

  def handle_info(%{channel: "teiserver_liveview_login_throttle", event: :release} = msg, state) do

    {:noreply,
     state
      |> assign(:remaining_capacity, msg.remaining_capacity)
      |> assign(:awaiting_release, msg.awaiting_release)
    }
  end

  def handle_info(%{channel: "teiserver_liveview_login_throttle", event: :accept_login} = msg, state) do

    {:noreply,
     state
      |> assign(:remaining_capacity, msg.remaining_capacity)
      |> assign(:recent_logins, msg.recent_logins)
    }
  end

  @impl true
  def handle_event("disconnect-all-bots", _event, socket) do
    Game.cast_lobby_organiser(socket.assigns.id, :disconnect_all_bots)

    {:noreply, socket}
  end
end
