defmodule TeiserverWeb.Matchmaking.QueueLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Account
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Game.QueueLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/battle/lobbies' class="btn btn-outline-primary">
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

    socket =
      socket
      |> Teiserver.ServerUserPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Queues", url: "/teiserver/game/queues")
      |> assign(:site_menu_active, "admin")
      |> assign(:view_colour, QueueLib.colours())
      |> assign(:messages, [])
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, :standard_live}}
  end

  @impl true
  def handle_params(%{"id" => id}, _opts, socket) do
    # case allow?(socket.assigns[:current_user], "Moderator") do
    #   true ->
    id = int_parse(id)
    PubSub.subscribe(Central.PubSub, "teiserver_queue:#{id}")
    queue = Matchmaking.get_queue(id)

    queue_state =
      if allow?(socket, "admin.dev.developer") do
        wait_pid = Matchmaking.get_queue_wait_pid(id)
        :sys.get_state(wait_pid)
      end

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
         |> assign(:queue_state, queue_state)
         |> assign_group_id
         |> assign_queue_info}
    end

    #   false ->
    #     {:noreply,
    #      socket
    #      |> redirect(to: ~p"/")}
    # end
  end

  @impl true
  def handle_info(%{channel: "teiserver_queue:" <> _}, %{assigns: assigns} = socket) do
    queue_state =
      if allow?(assigns.current_user, "admin.dev.developer") do
        wait_pid = Matchmaking.get_queue_wait_pid(assigns.id)
        :sys.get_state(wait_pid)
      end

    {:noreply,
     socket
     |> assign(:queue_state, queue_state)
     |> assign_group_id
     |> assign_queue_info}
  end

  defp assign_group_id(socket) do
    client = Account.get_client_by_id(socket.assigns.current_user.id)

    group_id =
      case client do
        nil -> nil
        %{party_id: nil} -> client.userid
        %{party_id: party_id} -> party_id
      end

    socket
    |> assign(group_id: group_id)
  end

  defp assign_queue_info(%{assigns: %{id: queue_id, group_id: group_id}} = socket) do
    queue_info = Matchmaking.get_queue_info_for_group(queue_id, group_id)

    socket
    |> assign(queue_info: queue_info)
    |> assign(system_time: System.system_time(:second))
  end

  defp page_title(:show), do: "Show Queue"
end
