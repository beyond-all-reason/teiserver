# A struct representing the in-memory version of Teiserver.Game.DBQueue
defmodule Teiserver.Data.QueueStruct do
  @enforce_keys [:id, :name, :team_size, :icon, :colour, :settings, :conditions, :map_list]
  defstruct [
    :id, :name, :team_size, :icon, :colour, :settings, :conditions, :map_list,
    current_search_time: 0, current_size: 0, contents: [], pid: nil
  ]
end

defmodule Teiserver.Data.Matchmaking do
  require Logger
  alias Teiserver.Game
  alias Teiserver.Data.QueueStruct
  alias Teiserver.Game.QueueServer

  @spec get_queue(Integer.t()) :: QueueStruct.t() | nil
  def get_queue(id) do
    ConCache.get(:queues, id)
  end

  @spec get_queue_and_info(Integer.t()) :: {QueueStruct.t(), Map.t()}
  def get_queue_and_info(id) do
    queue = ConCache.get(:queues, id)
    info = GenServer.call(queue.pid, :get_info)
    {queue, info}
  end

  @spec add_queue(QueueStruct.t()) :: :ok
  def add_queue(queue) do
    ConCache.update(:lists, :queues, fn value ->
      new_value =
        (value ++ [queue.id])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    {:ok, pid} =
      DynamicSupervisor.start_child(Teiserver.Game.QueueSupervisor, {
        QueueServer,
        data: %{queue: queue}
      })

    update_queue(%{queue | pid: pid})
  end

  @spec update_queue(QueueStruct.t()) :: :ok
  def update_queue(queue) do
    ConCache.put(:queues, queue.id, queue)
  end

  @spec list_queues :: [QueueStruct.t() | nil]
   def list_queues() do
    ConCache.get(:lists, :queues)
    |> Enum.map(fn queue_id -> ConCache.get(:queues, queue_id) end)
  end

  @spec list_queues([Integer.t()]) :: [QueueStruct.t() | nil]
  def list_queues(id_list) do
    id_list
    |> Enum.map(fn queue_id ->
      ConCache.get(:queues, queue_id)
    end)
  end

  @spec add_player_to_queue(Integer.t(), Integer.t(), pid()) :: :ok | :duplicate | :failed
  def add_player_to_queue(queue_id, player_id, pid) do
    case get_queue(queue_id) do
      nil ->
        :failed
      queue ->
        GenServer.call(queue.pid, {:add_player, player_id, pid})
    end
  end

  @spec remove_player_from_queue(Integer.t(), Integer.t()) :: :ok | :missing
  def remove_player_from_queue(queue_id, player_id) do
    case get_queue(queue_id) do
      nil ->
        :failed
      queue ->
        GenServer.call(queue.pid, {:remove_player, player_id})
    end
  end

  @spec add_queue_from_db(Map.t()) :: :ok
  def add_queue_from_db(queue) do
    convert_queue(queue)
    |> add_queue()
  end

  @spec convert_queue(Game.Queue.t()) :: QueueStruct.t()
  defp convert_queue(queue) do
    %QueueStruct{
      id: queue.id,
      name: queue.name,
      team_size: queue.team_size,
      icon: queue.icon,
      colour: queue.colour,
      settings: queue.settings,
      conditions: queue.conditions,
      map_list: queue.map_list
    }
  end

  @spec pre_cache_queues :: :ok
  def pre_cache_queues() do
    ConCache.insert_new(:lists, :queues, [])

    queue_count =
      Game.list_queues(
        limit: :infinity
      )
      |> Parallel.map(fn queue ->
        queue
        |> convert_queue
        |> add_queue
      end)
      |> Enum.count()

    Logger.info("pre_cache_queues, got #{queue_count} queues")
  end
end
