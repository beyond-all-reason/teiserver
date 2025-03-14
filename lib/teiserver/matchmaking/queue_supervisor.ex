defmodule Teiserver.Matchmaking.QueueSupervisor do
  @moduledoc """
  cluster wide supervisor for all matchmaking queues
  """

  use Horde.DynamicSupervisor
  alias Teiserver.Matchmaking.QueueServer

  def default_queues() do
    [
      QueueServer.init_state(%{
        id: "1v1",
        name: "Duel",
        team_size: 1,
        team_count: 2,
        engines: [%{version: "105.1.1-2590-gb9462a0 bar"}, %{version: "100.2.1-2143-test bar"}],
        games: [
          %{spring_game: "Beyond All Reason latest"},
          %{spring_game: "BAR test"}
        ]
      }),
      QueueServer.init_state(%{
        id: "2v2",
        name: "2v2",
        team_size: 2,
        team_count: 2,
        engines: [%{version: "105.1.1-2590-gb9462a0 bar"}, %{version: "100.2.1-2143-test bar"}],
        games: [
          %{spring_game: "Beyond All Reason latest"},
          %{spring_game: "BAR test"}
        ]
      })
    ]
  end

  def start_queue!(state) do
    case Horde.DynamicSupervisor.start_child(__MODULE__, {QueueServer, state}) do
      {:error, err} -> raise "Cannot start queue: #{inspect(err)}"
      _ -> :ok
    end
  end

  def terminate_queue(id) do
    case Teiserver.Matchmaking.QueueRegistry.lookup(id) do
      nil ->
        :ok

      pid ->
        Horde.DynamicSupervisor.terminate_child(__MODULE__, pid)
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
