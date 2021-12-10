defmodule TeiserverWeb.Matchmaking.QueueLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Data.Matchmaking
  alias Teiserver.{Game}
  alias Teiserver.Game.{QueueLib}

  import Central.Helpers.NumberHelper, only: [int_parse: 1]

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

    queues = Game.list_queues()
    |> Map.new(fn queue ->
      :ok = PubSub.subscribe(Central.PubSub, "teiserver_queue:#{queue.id}")

      {queue.id, Map.merge(queue, %{
        player_count: nil,
        last_wait_time: nil
      })}
    end)

    queue_membership = Map.keys(queues)
    |> Parallel.filter(fn queue_id ->
      player_map = Matchmaking.call_queue(queue_id, {:get, :player_map})
      Map.has_key?(player_map, socket.assigns[:current_user].id)
    end)

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Matchmaking", url: "/teiserver/game_live/queues")
      |> assign(:match_ready, nil)
      |> assign(:queue_membership, queue_membership)
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, QueueLib.colours())
      |> assign(:queues, queues)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "nomenu_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("join-queue", %{"queue_id" => queue_id}, %{assigns: assigns} = socket) do
    queue_id = int_parse(queue_id)
    Matchmaking.add_player_to_queue(queue_id, assigns[:current_user].id)

    {:noreply, socket}
  end

  def handle_event("leave-queue", %{"queue_id" => queue_id}, %{assigns: assigns} = socket) do
    queue_id = int_parse(queue_id)
    Matchmaking.remove_player_from_queue(queue_id, assigns[:current_user].id)

    {:noreply, socket}
  end

  def handle_event("ready-accept", _, %{assigns: assigns} = socket) do
    Matchmaking.player_accept(assigns[:match_ready], assigns[:current_user].id)

    {:noreply, socket
      |> assign(:match_ready, nil)
      |> assign(:queue_membership, [])}
  end

  def handle_event("ready-decline", _, %{assigns: assigns} = socket) do
    Matchmaking.player_decline(assigns[:match_ready], assigns[:current_user].id)

    {:noreply, socket
      |> assign(:match_ready, nil)
      |> assign(:queue_membership, [])}
  end

  @impl true
  def handle_info({:queue_periodic_update, queue_id, player_count, last_wait_time}, socket) do
    update_data = %{
      player_count: player_count,
      last_wait_time: last_wait_time
    }
    new_queue = Map.merge(socket.assigns.queues[queue_id], update_data)
    new_queues = Map.put(socket.assigns.queues, queue_id, new_queue)

    {
      :noreply,
      socket
        |> assign(:queues, new_queues)
    }
  end

  def handle_info({:client_action, :client_disconnect, userid}, %{assigns: assigns} = socket) do
    # TODO: Is this if socketment still needed? We're not using the legacy pubsub any more
    if userid == assigns[:current_user].id do
      {:noreply,
       socket
       |> redirect(to: Routes.ts_general_general_path(socket, :index))}
    else
      {:noreply, socket}
    end
  end

  # In theory never used
  def handle_info({:client_action, :client_connect, _userid}, socket) do
    {:noreply, socket}
  end

  # Queue related
  def handle_info({:queue_add_player, _queue_id, _userid}, socket) do
    {:noreply, socket}
  end

  def handle_info({:queue_remove_player, _queue_id, _userid}, socket) do
    {:noreply, socket}
  end

  def handle_info({:match_made, _queue_id, _lobby_id}, socket) do
    {:noreply, socket}
  end


  # Client action
  def handle_info({:client_action, :join_queue, _userid, queue_id}, %{assigns: assigns} = socket) do
    new_queue_membership = [queue_id | assigns[:queue_membership]]
      |> Enum.uniq

    {:noreply,
    socket
    |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info({:client_action, :leave_queue, _userid, queue_id}, %{assigns: assigns} = socket) do
    new_queue_membership = List.delete(assigns[:queue_membership], queue_id)

    {:noreply,
      socket
      |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info({:client_action, _topic, _userid, _data}, socket) do
    {:noreply, socket}
  end

  # Client message
  def handle_info({:client_message, :matchmaking, {:join_battle, _lobby_id}}, socket) do
    Logger.warn("index.ex Join battle")
    {:noreply, socket}
  end

  def handle_info({:client_message, :matchmaking, {:match_ready, queue_id}}, socket) do
    Logger.warn("index.ex Match ready")
    {:noreply,
    socket
    |> assign(:match_ready, queue_id)}
  end

  def handle_info({:client_message, _topic, _data}, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_queue_all_queues")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{socket.assigns[:current_user].id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_action_updates:#{socket.assigns[:current_user].id}")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end
end
