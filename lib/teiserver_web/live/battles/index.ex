defmodule TeiserverWeb.BattleLive.Index do
  use TeiserverWeb, :live_view

  alias Teiserver
  alias Teiserver.Battle

  @impl true
  def mount(_params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call
    |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
    |> add_breadcrumb(name: "Battles", url: "/teiserver/battles")
    |> assign(:sidemenu_active, "teiserver")
    |> assign(:colours, Central.Helpers.StylingHelper.colours(:primary2))

    {:ok, assign(socket, :battles, list_battles())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end

  defp list_battles do
    Battle.list_battles()
  end
end
