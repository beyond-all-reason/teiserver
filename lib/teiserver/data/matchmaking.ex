defmodule Teiserver.Data.QueueStruct do
  @moduledoc """
  A struct representing the in-memory version of Teiserver.Game.DBQueue
  """
  @enforce_keys ~w(id name team_size team_count icon colour settings conditions map_list)a
  defstruct [
    :id,
    :name,
    :team_size,
    :team_count,
    :icon,
    :colour,
    :settings,
    :conditions,
    :map_list,
    current_search_time: 0,
    current_size: 0,
    contents: []
  ]
end

defmodule Teiserver.Data.QueueGroup do
  @moduledoc false
  @enforce_keys ~w(id members rating avoid count join_time wait_time)a
  defstruct [
    id: nil,
    members: [],
    rating: nil,
    avoid: [],
    count: nil,
    join_time: nil,
    wait_time: nil,

    bucket: nil,
    search_distance: 0,
    max_distance: 0
  ]
end

defmodule Teiserver.Data.Matchmaking do
  require Logger
  alias Teiserver.{Account, Game}
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Data.{QueueStruct, QueueGroup}
  alias Teiserver.Game.{QueueWaitServer, QueueMatchServer}
  alias Teiserver.Data.Types, as: T

  @spec get_queue(Integer.t()) :: QueueStruct.t() | nil
  def get_queue(id) do
    Central.cache_get(:teiserver_queues, id)
  end

  @spec get_queue_wait_pid(T.queue_id()) :: pid() | nil
  def get_queue_wait_pid(id) when is_integer(id) do
    case Horde.Registry.lookup(Teiserver.QueueWaitRegistry, id) do
      [{pid, _}] ->
        pid
      _ ->
        nil
    end
  end

  @spec call_queue_wait(T.queue_id(), any) :: any | nil
  def call_queue_wait(queue_id, message) when is_integer(queue_id) do
    case get_queue_wait_pid(queue_id) do
      nil -> nil
      pid ->
        try do
          GenServer.call(pid, message)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @spec cast_queue_wait(T.queue_id(), any) :: any
  def cast_queue_wait(queue_id, msg) do
    case get_queue_wait_pid(queue_id) do
      nil -> nil
      pid -> GenServer.cast(pid, msg)
    end
  end

  @spec get_queue_match_pid(T.mm_match_id()) :: pid() | nil
  def get_queue_match_pid(id) do
    case Horde.Registry.lookup(Teiserver.QueueMatchRegistry, id) do
      [{pid, _}] ->
        pid
      _ ->
        nil
    end
  end

  @spec call_queue_match(T.queue_id(), any) :: any | nil
  def call_queue_match(queue_id, message) when is_integer(queue_id) do
    case get_queue_match_pid(queue_id) do
      nil -> nil
      pid ->
        try do
          GenServer.call(pid, message)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @spec cast_queue_match(T.queue_id(), any) :: any
  def cast_queue_match(queue_id, msg) do
    case get_queue_match_pid(queue_id) do
      nil -> nil
      pid -> GenServer.cast(pid, msg)
    end
  end

  @spec create_match([QueueGroup.t()], T.queue_id()) :: {pid, String.t()}
  def create_match(group_list, queue_id) do
    Logger.info("#{__ENV__.file}:#{__ENV__.line}\ncreate_match: #{inspect group_list}")

    {pid, match_id} = add_match_server(queue_id, group_list)
    {pid, match_id}
  end

  @spec add_match_server(T.queue_id(), [QueueGroup.t()]) :: {pid, String.t()}
  def add_match_server(queue_id, group_list) do
    match_id = UUID.uuid1()

    {:ok, pid} = DynamicSupervisor.start_child(Teiserver.Game.QueueSupervisor, {
      QueueMatchServer,
      data: %{
        match_id: match_id,
        queue_id: queue_id,
        group_list: group_list
      }
    })

    {pid, match_id}
  end

  @spec get_queue_and_info(T.queue_id()) :: {QueueStruct.t(), Map.t()}
  def get_queue_and_info(id) when is_integer(id) do
    queue = Central.cache_get(:teiserver_queues, id)
    info = call_queue_wait(id, :get_info)
    {queue, info}
  end

  @spec get_queue_info(T.queue_id()) :: Map.t()
  def get_queue_info(id) when is_integer(id) do
    call_queue_wait(id, :get_info)
  end

  @spec add_queue(QueueStruct.t()) :: :ok | {:error, any}
  def add_queue(nil), do: {:error, "no queue"}
  def add_queue(queue) do
    Central.cache_update(:lists, :queues, fn value ->
      new_value =
        ([queue.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    update_queue(queue)

    result = DynamicSupervisor.start_child(Teiserver.Game.QueueSupervisor, {
      QueueWaitServer,
      data: %{queue: queue}
    })
    case result do
      {:error, err} ->
        Logger.error("Error starting QueueWaitServer: #{__ENV__.file}:#{__ENV__.line}\n#{inspect err}")
        {:error, err}
      {:ok, _pid} ->
        :ok
    end
  end

  @spec update_queue(QueueStruct.t()) :: :ok
  def update_queue(queue) do
    Central.cache_put(:teiserver_queues, queue.id, queue)
  end

  @spec list_queue_ids :: [non_neg_integer()]
  def list_queue_ids() do
    Central.cache_get(:lists, :queues)
  end

  @spec list_queues :: [QueueStruct.t() | nil]
  def list_queues() do
    list_queue_ids()
      |> Enum.map(fn queue_id -> Central.cache_get(:teiserver_queues, queue_id) end)
  end

  @spec list_queues([Integer.t()]) :: [QueueStruct.t() | nil]
  def list_queues(id_list) do
    id_list
      |> Enum.map(fn queue_id ->
        Central.cache_get(:teiserver_queues, queue_id)
      end)
  end

  @spec get_queue_by_name(String.t()) :: QueueStruct.t() | nil
  def get_queue_by_name(name) do
    search_name = name
      |> String.trim()
      |> String.downcase()

    list_queues()
      |> Enum.find(fn %{name: queue_name} ->
        String.downcase(queue_name) == search_name
      end)
  end

  @spec add_user_to_queue(T.queue_id(), T.userid()) :: :ok | :not_party_leader | :duplicate | :failed | :missing | :no_queue
  def add_user_to_queue(queue_id, userid) do
    queue = get_queue(queue_id)
    client = Account.get_client_by_id(userid)

    if queue == nil do
      :no_queue
    else
      if client.party_id do
        party = Account.get_party(client.party_id)
        if party.leader == userid do
          party
            |> make_group_from_party(queue)
            |> do_add_group_to_queue(queue_id)
        else
          :not_party_leader
        end
      else
        userid
          |> make_group_from_userid(queue)
          |> do_add_group_to_queue(queue_id)
      end
    end
  end

  @spec do_add_group_to_queue(T.userid(), T.queue_id()) :: :ok | :duplicate | :failed | :missing
  defp do_add_group_to_queue(queue_group, queue_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :missing

      pid ->
        GenServer.call(pid, {:add_group, queue_group})
    end
  end

  @spec get_user_rating_for_queue(T.userid(), T.queue_id()) :: float()
  defp get_user_rating_for_queue(userid, queue) do
    rating_type = cond do
      queue.settings["rating_type"] != nil -> queue.settings["rating_type"]
      queue.team_size == 1 -> "Duel"
      true -> "Team"
    end

    BalanceLib.get_user_rating_value(userid, rating_type)
  end

  @spec make_group_from_userid(T.userid, T.queue()) :: QueueGroup.t()
  def make_group_from_userid(userid, queue) when is_integer(userid) do
    rating_value = get_user_rating_for_queue(userid, queue)

    %QueueGroup{
      id: userid,
      members: [userid],
      rating: rating_value,
      avoid: [],
      count: 1,
      wait_time: 0,
      join_time: System.system_time(:second),

      bucket: nil,
      search_distance: 0,
      max_distance: nil
    }
  end

  @spec make_group_from_party(T.party(), T.queue()) :: QueueGroup.t()
  def make_group_from_party(party, queue) do
    rating_value = party.members
      |> Enum.map(fn userid ->
        get_user_rating_for_queue(userid, queue)
      end)
      |> Enum.max

    %QueueGroup{
      id: party.id,
      members: party.members,
      rating: rating_value,
      avoid: [],
      count: Enum.count(party.members),
      wait_time: 0,
      join_time: System.system_time(:second),

      bucket: nil,
      search_distance: 0,
      max_distance: nil
    }
  end

  @spec remove_group_from_queue(T.queue_id(), T.userid() | T.party_id()) :: :ok | :missing
  def remove_group_from_queue(queue_id, userid) when is_integer(userid) do
    client = Account.get_client_by_id(userid)

    if client.party_id do
      party = Account.get_party(client.party_id)
      if party.leader == userid do
        do_remove_group_from_queue(party.id, queue_id)
      else
        :not_party_leader
      end
    else
      do_remove_group_from_queue(userid, queue_id)
    end
  end

  # When group is a party
  def remove_group_from_queue(queue_id, party_id) do
    Account.party_leave_queue(party_id, queue_id)
    do_remove_group_from_queue(party_id, queue_id)
  end

  @spec do_remove_group_from_queue(T.userid() | T.party_id(), T.queue_id()) :: :ok | :missing
  def do_remove_group_from_queue(group_id, queue_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :missing

      pid ->
        GenServer.call(pid, {:remove_group, group_id})
    end
  end

  @spec re_add_group_to_queue(QueueGroup.t(), T.queue_id()) :: :ok
  def re_add_group_to_queue(group, queue_id) do
    cast_queue_wait(queue_id, {:re_add_group, group})
    :ok
  end

  @spec player_accept(T.mm_match_id(), T.userid()) :: :ok | :missing
  def player_accept(match_id, player_id) do
    case get_queue_match_pid(match_id) do
      nil ->
        :missing

      pid ->
        GenServer.cast(pid, {:player_accept, player_id})
        :ok
    end
  end

  @spec player_decline(T.mm_match_id(), Integer.t()) :: :ok | :missing
  def player_decline(match_id, player_id) do
    case get_queue_match_pid(match_id) do
      nil ->
        :missing

      pid ->
        GenServer.cast(pid, {:player_decline, player_id})
        :ok
    end
  end

  @spec add_queue_from_db(Map.t()) :: :ok
  def add_queue_from_db(queue) do
    queue
      |> convert_queue()
      |> add_queue()
  end

  def refresh_queue_from_db(queue) do
    cast_queue_wait(queue.id, {:refresh_from_db, queue})
  end

  @spec convert_queue(Game.Queue.t()) :: QueueStruct.t()
  defp convert_queue(queue) do
    %QueueStruct{
      id: queue.id,
      name: queue.name,
      team_size: queue.team_size,
      team_count: queue.team_count || 2,
      icon: queue.icon,
      colour: queue.colour,
      settings: queue.settings,
      conditions: queue.conditions,
      map_list: queue.map_list
    }
  end

  @spec pre_cache_queues :: :ok
  def pre_cache_queues() do
    Central.cache_insert_new(:lists, :queues, [])

    queue_count =
      Game.list_queues(limit: :infinity)
      |> Parallel.map(fn queue ->
        queue
        |> convert_queue
        |> add_queue
      end)
      |> Enum.count()

    Logger.info("pre_cache_queues, got #{queue_count} queues")
  end
end
