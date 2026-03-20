defmodule Teiserver.Matchmaking.QueueSupervisor do
  @moduledoc """
  cluster wide supervisor for all matchmaking queues
  """

  alias Horde.DynamicSupervisor, as: HordeSupervisor
  alias Teiserver.Asset
  alias Teiserver.Matchmaking.PairingRoom
  alias Teiserver.Matchmaking.QueueRegistry
  alias Teiserver.Matchmaking.QueueServer

  use Horde.DynamicSupervisor

  def default_queues() do
    engines =
      case Asset.get_engine(in_matchmaking: true) do
        nil -> []
        e -> [%{version: e.name}]
      end

    games =
      case Asset.get_game(in_matchmaking: true) do
        nil -> []
        g -> [%{spring_game: g.name}]
      end

    [
      QueueServer.init_state(%{
        id: "1v1",
        name: "Duel",
        team_size: 1,
        team_count: 2,
        engines: engines,
        games: games,
        maps: Asset.get_maps_for_queue("1v1"),
        algo: :bruteforce_filter
      }),
      QueueServer.init_state(%{
        id: "2v2",
        name: "2v2",
        team_size: 2,
        team_count: 2,
        engines: engines,
        games: games,
        maps: Asset.get_maps_for_queue("2v2"),
        algo: :bruteforce_filter
      })
    ]
  end

  def start_queue!(state) do
    case HordeSupervisor.start_child(__MODULE__, {QueueServer, state}) do
      {:error, err} -> raise "Cannot start queue: #{inspect(err)}"
      {:ok, pid} -> {:ok, pid}
    end
  end

  def terminate_queue(id) do
    case QueueRegistry.lookup(id) do
      nil ->
        :ok

      pid ->
        HordeSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @spec start_pairing_room(QueueServer.id(), QueueServer.queue(), [PairingRoom.team()], timeout()) ::
          {:ok, pid()} | {:error, term()}
  def start_pairing_room(queue_id, queue, teams, timeout) do
    HordeSupervisor.start_child(
      __MODULE__,
      {PairingRoom, {queue_id, queue, teams, timeout}}
    )
  end

  def start_link(init_arg) do
    {:ok, sup} = HordeSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)

    Enum.each(default_queues(), &start_queue!/1)

    {:ok, sup}
  end

  @impl HordeSupervisor
  def init(_) do
    HordeSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
