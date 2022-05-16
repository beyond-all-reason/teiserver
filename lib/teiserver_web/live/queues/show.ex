defmodule TeiserverWeb.Matchmaking.QueueLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Game.QueueLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/battle/lobbies' class="btn btn-outline-primary">
      <i class="fa-solid fa-fw fa-swords"></i>
      Battles
    </a>
  """

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    extra_content = @extra_menu_content

    socket = socket
      |> Teiserver.ServerUserPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Queues", url: "/teiserver/game/queues")
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:view_colour, QueueLib.colours())
      |> assign(:messages, [])
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _opts, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
      true ->
        id = int_parse(id)
        PubSub.subscribe(Central.PubSub, "teiserver_queue_wait:#{id}")
        queue = Matchmaking.get_queue(id)
        queue_state = Matchmaking.call_queue_wait(id, :get_state)

        case queue do
          nil ->
            {:noreply,
            socket
            |> redirect(to: Routes.ts_game_queue_path(socket, :index))}

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
      |> assign(:queue_state, Matchmaking.call_queue_wait(assigns.id, :get_state))
    }
  end

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
