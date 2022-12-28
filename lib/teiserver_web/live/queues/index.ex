defmodule TeiserverWeb.Matchmaking.QueueLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Data.Matchmaking
  alias Teiserver.{Game, Client}
  alias Teiserver.Game.{QueueLib}

  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    client = Client.get_client_by_id(socket.assigns[:current_user].id)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_queue_all_queues")

    db_queues = Game.list_queues()
      |> Map.new(fn queue ->
        :ok = PubSub.subscribe(Central.PubSub, "teiserver_queue_wait:#{queue.id}")
        :ok = PubSub.subscribe(Central.PubSub, "teiserver_queue_match:#{queue.id}")

        {queue.id, queue}
      end)

    queue_info = db_queues
      |> Map.keys()
      |> Map.new(fn id ->
        {id, Matchmaking.get_queue_info(id)}
      end)

    queue_membership = Map.keys(db_queues)
      |> Parallel.reject(fn queue_id ->
        p = Matchmaking.get_queue_wait_pid(queue_id)
        if p != nil do
          state = :sys.get_state(p)

          state.groups_map
            |> Enum.filter(fn {_group_id, %{members: members}} -> Enum.member?(members, socket.assigns[:current_user].id) end)
            |> Enum.empty?()
        else
          true
        end
      end)

    is_admin = allow?(socket.assigns[:current_user], "teiserver.staff.admin")

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Matchmaking", url: "/teiserver/game_live/queues")
      |> assign(:client, client)
      |> assign(:queue_membership, queue_membership)
      |> assign(:view_colour, QueueLib.colours())
      |> assign(:site_menu_active, "teiserver_admin")
      |> assign(:db_queues, db_queues)
      |> assign(:queue_info, queue_info)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:match_id, nil)
      |> assign(:is_admin, is_admin)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("join-queue", %{"queue_id" => queue_id}, %{assigns: assigns} = socket) do
    queue_id = int_parse(queue_id)
    Matchmaking.add_user_to_queue(queue_id, assigns[:current_user].id)

    {:noreply, socket}
  end

  def handle_event("leave-queue", %{"queue_id" => queue_id}, %{assigns: assigns} = socket) do
    queue_id = int_parse(queue_id)
    Matchmaking.remove_group_from_queue(queue_id, assigns[:current_user].id)

    {:noreply, socket}
  end

  def handle_event("ready-accept", _, %{assigns: assigns} = socket) do
    Matchmaking.player_accept(assigns[:match_id], assigns[:current_user].id)

    {:noreply, socket
      |> assign(:match_id, nil)
      |> assign(:queue_membership, [])}
  end

  def handle_event("ready-decline", _, %{assigns: assigns} = socket) do
    Matchmaking.player_decline(assigns[:match_id], assigns[:current_user].id)

    {:noreply, socket
      |> assign(:match_id, nil)
      |> assign(:queue_membership, [])}
  end

  @impl true
  def handle_info({:queue_periodic_update, queue_id, member_count, mean_wait_time}, socket) do
    new_data = %{
      member_count: member_count,
      mean_wait_time: mean_wait_time
    }

    new_info = socket.assigns[:queue_info]
      |> Map.put(queue_id, new_data)

    {
      :noreply,
      socket
        |> assign(:queue_info, new_info)
    }
  end

  def handle_info({:client_action, :client_connect, _userid}, socket) do
    {:noreply,
      socket
        |> assign(:client, Client.get_client_by_id(socket.assigns[:current_user].id))
    }
  end

  def handle_info({:client_action, :client_disconnect, userid}, socket) do
    socket.assigns[:queue_membership]
      |> Enum.each(fn queue_id ->
        Matchmaking.remove_group_from_queue(queue_id, userid)
      end)

    {:noreply,
      socket
        |> assign(:client, nil)
    }
  end

  # Queue wait
  def handle_info({:queue_wait, :queue_add_user, _queue_id, _userid}, socket) do
    {:noreply, socket}
  end

  def handle_info({:queue_wait, :queue_remove_user, _queue_id, _userid}, socket) do
    {:noreply, socket}
  end

  def handle_info({:queue_wait, :match_attempt, _queue_id, _match_id}, socket) do
    {:noreply, socket}
  end

  # Queue match
  def handle_info({:queue_match, :match_attempt, _queue_id, _lobby_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:queue_match, :match_made, _queue_id, _lobby_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:queue_wait, :queue_remove_group, _queue_id, _userid}, socket) do
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
  def handle_info(data = %{
    channel: "teiserver_client_messages:" <> _userid_str,
    event: :matchmaking,
    sub_event: :match_ready
  }, socket) do
    Logger.warn("index.ex Match ready")
    {:noreply,
      socket
      |> assign(:match_id, data.match_id)
    }
  end

  def handle_info(%{
    channel: "teiserver_client_messages:" <> _userid_str,
    event: :matchmaking,
    sub_event: :joined_queue,
    queue_id: queue_id
  }, socket) do
    new_queue_membership = socket.assigns.queue_membership ++ [queue_id]
      |> Enum.uniq

    {:noreply,
      socket
        |> assign(:queue_membership, new_queue_membership)
    }
  end

  def handle_info(%{
    channel: "teiserver_client_messages:" <> _userid_str,
    event: :matchmaking,
    sub_event: :left_queue,
    queue_id: queue_id
  }, socket) do
    new_queue_membership = socket.assigns.queue_membership
      |> List.delete(queue_id)

    {:noreply,
      socket
        |> assign(:queue_membership, new_queue_membership)
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _userid_str}, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{socket.assigns[:current_user].id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_action_updates:#{socket.assigns[:current_user].id}")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end
end
