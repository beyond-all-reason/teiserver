defmodule TeiserverWeb.AdminDashLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Client, User}
  alias Teiserver.Account.UserLib

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/teiserver/admin/dashboard")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, Central.Admin.AdminLib.colours())
      |> assign(:telemetry_loading, true)
      |> assign(:telemetry_client, nil)
      |> assign(:telemetry_battle, nil)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))

    {:ok, socket, layout: {CentralWeb.LayoutView, "blank_live.html"}}
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
  def handle_info({:teiserver_telemetry, data}, socket) do
    {:noreply,
      socket
      |> assign(:telemetry_loading, false)
      |> assign(:telemetry_client, data.client)
      |> assign(:telemetry_battle, data.battle)
    }
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_telemetry")

    socket
    |> assign(:page_title, "Listing Clients")
    |> assign(:client, nil)
  end
end
