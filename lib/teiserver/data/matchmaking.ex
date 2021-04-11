# A struct representing the in-memory version of Teiserver.Game.DBQueue
defmodule Teiserver.Data.QueueStruct do
  @enforce_keys [:name, :team_size, :icon, :colour, :settings, :conditions, :map_list]
  defstruct [
    :name, :team_size, :icon, :colour, :settings, :conditions, :map_list,
    current_search_time: 0, current_size: 0, contents: []
  ]
end

defmodule Teiserver.Data.Matchmaking do
  require Logger
  alias Teiserver.Game
  alias Teiserver.Data.QueueStruct

  @spec get_queue(Integer.t()) :: QueueStruct.t() | nil
  def get_queue(id) do
    ConCache.get(:queues, id)
  end

  @spec add_queue(QueueStruct.t()) :: :ok
  def add_queue(queue) do
    ConCache.update(:lists, :queues, fn value ->
      new_value =
        (value ++ [queue.id])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    update_queue(queue)
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

  @spec convert_queue(Game.Queue.t()) :: QueueStruct.t()
  defp convert_queue(queue) do
    %QueueStruct{
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
