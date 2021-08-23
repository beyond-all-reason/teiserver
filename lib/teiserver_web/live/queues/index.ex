defmodule TeiserverWeb.Matchmaking.QueueLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.Game
  alias Teiserver.Game.{Queue, QueueLib}

  @base_extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/battle/lobbies' class="btn btn-outline-primary">
      <i class="fas fa-fw fa-swords"></i>
      Battles
    </a>
  """

  @client_extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/admin/client' class="btn btn-outline-primary">
      <i class="fas fa-fw fa-plug"></i>
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
      @base_extra_menu_content <> @client_extra_menu_content
    else
      @base_extra_menu_content
    end

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Matchmaking", url: "/teiserver/game_live/queues")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, QueueLib.colours())
      |> assign(:queues, Game.list_queues())
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "blank_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:global_battle_updated, _battle_id, :battle_opened}, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end
end
