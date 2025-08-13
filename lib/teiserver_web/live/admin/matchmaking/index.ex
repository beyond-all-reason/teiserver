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

        Matchmaking.subscribe_to_queue_updates()

        {:ok, get_queues(socket)}

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
  def handle_info(
        %{
          channel: "matchmaking_queues",
          event: :queue_updated,
          queue_id: queue_id,
          stats: stats
        },
        socket
      ) do
    queues = socket.assigns.queues

    updated_queues =
      Enum.map(queues, fn {id, queue} ->
        if id == queue_id do
          {id,
           Map.merge(queue, %{
             stats: stats
           })}
        else
          {id, queue}
        end
      end)

    {:noreply, assign(socket, :queues, updated_queues)}
  end

  defp get_queues(socket) do
    queues = Matchmaking.list_queues_with_stats()

    socket
    |> assign(:queues, queues)
  end
end
