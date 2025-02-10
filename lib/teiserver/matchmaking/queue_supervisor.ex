defmodule Teiserver.Matchmaking.QueueSupervisor do
  @moduledoc """
  cluster wide supervisor for all matchmaking queues
  """

  use Horde.DynamicSupervisor
  alias Teiserver.Matchmaking.QueueServer

  @spec default_queues() :: [
          %{
            id: any(),
            members: any(),
            monitors: [],
            pairings: [],
            queue: %{
              engines: any(),
              games: any(),
              maps: any(),
              name: any(),
              ranked: true,
              team_count: any(),
              team_size: any()
            },
            settings: %{
              :max_distance => any(),
              :pairing_timeout => any(),
              :tick_interval_ms => any(),
              optional(any()) => any()
            }
          },
          ...
        ]
  def default_queues() do
    [
      QueueServer.init_state(%{
        id: "1v1",
        name: "Duel",
        team_size: 1,
        team_count: 2
      }),
      QueueServer.init_state(%{
        id: "2v2",
        name: "2v2",
        team_size: 2,
        team_count: 2
      })
    ]
  end

  def start_queue!(state) do
    case Horde.DynamicSupervisor.start_child(__MODULE__, {QueueServer, state}) do
      {:error, err} -> raise "Cannot start queue: #{inspect(err)}"
      _ -> :ok
    end
  end

  def start_link(init_arg) do
    {:ok, sup} = Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)

    Enum.each(default_queues(), &start_queue!/1)

    {:ok, sup}
  end

  @impl true
  def init(_) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
