defmodule TeiserverWeb.Matchmaking.QueueLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver
  alias Teiserver.Data.Matchmaking
  alias Teiserver.{Game, Client}
  alias Teiserver.Game.{QueueLib}

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    client = Client.get_client_by_id(socket.assigns[:current_user].id)

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_all_queues")

    db_queues =
      Game.list_queues()
      |> Enum.filter(fn queue ->
        Map.get(queue.settings, "enabled", true)
      end)
      |> Map.new(fn queue ->
        {queue.id, queue}
      end)

    queue_info =
      db_queues
      |> Map.keys()
      |> Map.new(fn id ->
        {id, Matchmaking.get_queue_info(id)}
      end)

    queue_membership =
      Map.keys(db_queues)
      |> ParallelStream.reject(fn queue_id ->
        p = Matchmaking.get_queue_wait_pid(queue_id)

        if p != nil do
          state = :sys.get_state(p)

          state.groups_map
          |> Enum.filter(fn {_group_id, %{members: members}} ->
            Enum.member?(members, socket.assigns[:current_user].id)
          end)
          |> Enum.empty?()
        else
          true
        end
      end)

    is_admin = allow?(socket.assigns[:current_user], "Admin")

    socket =
      socket
      |> add_breadcrumb(name: "Matchmaking", url: "/teiserver/game_live/queues")
      |> assign(:client, client)
      |> assign(:queue_membership, queue_membership)
      |> assign(:view_colour, QueueLib.colours())
      |> assign(:site_menu_active, "matchmaking")
      |> assign(:db_queues, db_queues)
      |> assign(:queue_info, queue_info)
      |> assign(:match_id, nil)
      |> assign(:is_admin, is_admin)

    {:ok, socket}
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

    {:noreply,
     socket
     |> assign(:match_id, nil)
     |> assign(:queue_membership, [])}
  end

  def handle_event("ready-decline", _, %{assigns: assigns} = socket) do
    Matchmaking.player_decline(assigns[:match_id], assigns[:current_user].id)

    {:noreply,
     socket
     |> assign(:match_id, nil)
     |> assign(:queue_membership, [])}
  end

  @impl true
  def handle_info(%{event: :all_queues_periodic_update} = event, socket) do
    new_data = %{
      group_count: event.group_count,
      mean_wait_time: event.mean_wait_time
    }

    new_info =
      socket.assigns[:queue_info]
      |> Map.put(event.queue_id, new_data)

    {
      :noreply,
      socket
      |> assign(:queue_info, new_info)
    }
  end

  def handle_info(%{channel: "teiserver_all_queues"}, socket) do
    {:noreply, socket}
  end

  # Client action
  def handle_info(
        %{channel: "teiserver_client_messages:" <> _, event: :joined_queue, queue_id: queue_id},
        %{assigns: assigns} = socket
      ) do
    new_queue_membership =
      [queue_id | assigns[:queue_membership]]
      |> Enum.uniq()

    {:noreply,
     socket
     |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _, event: :left_queue, queue_id: queue_id},
        %{assigns: assigns} = socket
      ) do
    new_queue_membership = List.delete(assigns[:queue_membership], queue_id)

    {:noreply,
     socket
     |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _, event: :match_declined, queue_id: queue_id},
        %{assigns: assigns} = socket
      ) do
    new_queue_membership = List.delete(assigns[:queue_membership], queue_id)

    {:noreply,
     socket
     |> assign(:queue_membership, new_queue_membership)
     |> assign(:queue_membership, [])}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _, event: :match_created, queue_id: _queue_id},
        %{assigns: _assigns} = socket
      ) do
    {:noreply,
     socket
     |> assign(:queue_membership, [])}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    {:noreply,
     socket
     |> assign(:client, Client.get_client_by_id(socket.assigns[:current_user].id))
     |> assign(:queue_membership, [])}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    userid = socket.assigns[:current_user].id

    socket.assigns[:queue_membership]
    |> Enum.each(fn queue_id ->
      Matchmaking.remove_group_from_queue(queue_id, userid)
    end)

    {:noreply,
     socket
     |> assign(:client, nil)
     |> assign(:queue_membership, [])}
  end

  def handle_info(
        %{
          channel: "teiserver_client_messages:" <> _userid_str,
          event: :matchmaking,
          sub_event: :match_ready
        } = data,
        socket
      ) do
    Logger.warn("index.ex Match ready")

    {:noreply,
     socket
     |> assign(:match_id, data.match_id)}
  end

  def handle_info(
        %{
          channel: "teiserver_client_messages:" <> _userid_str,
          event: :matchmaking,
          sub_event: :joined_queue,
          queue_id: queue_id
        },
        socket
      ) do
    new_queue_membership =
      (socket.assigns.queue_membership ++ [queue_id])
      |> Enum.uniq()

    {:noreply,
     socket
     |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info(
        %{
          channel: "teiserver_client_messages:" <> _userid_str,
          event: :matchmaking,
          sub_event: :left_queue,
          queue_id: queue_id
        },
        socket
      ) do
    new_queue_membership =
      socket.assigns.queue_membership
      |> List.delete(queue_id)

    {:noreply,
     socket
     |> assign(:queue_membership, new_queue_membership)}
  end

  def handle_info(
        %{
          channel: "teiserver_client_messages:" <> _userid_str,
          event: :client_updated,
          client: client
        },
        socket
      ) do
    {:noreply,
     socket
     |> assign(:client, client)}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _userid_str}, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{socket.assigns[:current_user].id}"
      )

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end
end
