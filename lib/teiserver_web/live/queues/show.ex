defmodule TeiserverWeb.MatchmakingLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Game.QueueLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @extra_menu_content """
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
      @extra_menu_content
    end

    socket = socket
      |> Teiserver.ServerUserPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Queues", url: "/teiserver/admin/queues")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, QueueLib.colours())
      |> assign(:messages, [])
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "blank_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _opts, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
      true ->
        id = int_parse(id)
        PubSub.subscribe(Central.PubSub, "teiserver_queue:#{id}")
        queue = Matchmaking.get_queue(id)
        queue_state = Matchmaking.call_queue(id, :get_state)

        case queue do
          nil ->
            {:noreply,
            socket
            |> redirect(to: Routes.ts_admin_matchmaking_index_path(socket, :index))}

          _ ->
            {:noreply,
            socket
            |> assign(:page_title, page_title(socket.assigns.live_action))
            |> add_breadcrumb(name: queue.name, url: "/teiserver/admin/queues/#{id}")
            |> assign(:id, id)
            |> assign(:queue, queue)
            |> assign(:queue_state, queue_state)}
        end
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info(_msg, %{assigns: assigns} = socket) do
    {:noreply,
      socket
      |> assign(:queue_state, Matchmaking.call_queue(assigns.id, :get_state))
    }
  end

  # @impl true
  # def handle_event("start-Coordinator", _event, %{assigns: %{id: id}} = socket) do
  #   Lobby.start_coordinator_mode(id)
  #   battle = %{socket.assigns.battle | coordinator_mode: true}
  #   {:noreply, assign(socket, :battle, battle)}
  # end

  defp page_title(:show), do: "Show Queue"
  # defp index_redirect(socket) do
  #   {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  # end
  # defp maybe_index_redirect(socket) do
  #   if socket.assigns[:battle] == nil do
  #     index_redirect(socket)
  #   else
  #     socket
  #   end
  # end
end
