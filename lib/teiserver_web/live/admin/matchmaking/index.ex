defmodule TeiserverWeb.Admin.MatchmakingLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.Matchmaking

  @impl true
  def mount(_params, _session, socket) do
    case allow?(socket.assigns[:current_user], "Admin") do
      true ->
        socket =
          socket
          |> assign(:site_menu_active, "matchmaking")
          |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
          |> assign(:queues, [])
          |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
          |> add_breadcrumb(name: "Matchmaking", url: "/admin/matchmaking")

        :timer.send_interval(5_000, :refresh_queues)

        {:ok, socket}

      false ->
        {:ok,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, get_queues(socket)}
  end

  @impl true
  def handle_info(:refresh_queues, socket) do
    :timer.send_interval(5_000, :refresh_queues)
    {:noreply, get_queues(socket)}
  end

  defp get_queues(socket) do
    queues = Matchmaking.list_queues()

    queues_with_info = Enum.map(queues, &enrich_queue_data/1)

    socket
    |> assign(:queues, queues_with_info)
  end

  defp enrich_queue_data({queue_id, queue}) do
    stats = get_queue_stats(queue_id)
    total_players = get_queue_player_count(queue_id)

    {queue_id,
     Map.merge(queue, %{
       total_players: total_players,
       stats: stats
     })}
  end

  defp get_queue_stats(queue_id) do
    case Matchmaking.get_stats(queue_id) do
      {:ok, stats} -> stats
      _ -> %{total_joined: 0, total_left: 0, total_matched: 0, total_wait_time_s: 0}
    end
  end

  defp get_queue_player_count(queue_id) do
    queue_id
    |> Matchmaking.QueueRegistry.lookup()
    |> get_queue_state()
    |> calculate_player_count()
  end

  defp get_queue_state(nil), do: nil

  defp get_queue_state(pid) do
    case GenServer.call(pid, :get_state, 1000) do
      {:ok, state} -> state
      _ -> nil
    end
  end

  defp calculate_player_count(nil), do: 0

  defp calculate_player_count(state) do
    state.members
    |> Enum.reduce(0, fn member, acc ->
      acc + length(member.player_ids)
    end)
  end
end
