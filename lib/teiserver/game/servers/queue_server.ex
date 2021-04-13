defmodule Teiserver.Game.QueueServer do
  use GenServer
  require Logger

  def handle_call({:add_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} = case Enum.member?(state.players, userid) do
      true ->
        {:duplicate, state}
      false ->
        player_item = :erlang.system_time(:seconds)
        new_state = %{state | players: state.players ++ [userid], player_map: Map.put(state.player_map, userid, player_item)}
        {:ok, new_state}
    end
    {:reply, resp, new_state}
  end

  def handle_call({:remove_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} = case Enum.member?(state.players, userid) do
      true ->
        new_state = %{state |
          players: Enum.reject(state.players, fn u -> u == userid end),
          player_map: Map.drop(state.player_map, [userid])
        }
        {:ok, new_state}
      false ->
        {:missing, state}
    end
    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      last_wait_time: state.last_wait_time,
      player_count: Enum.count(state.players)
    }
    {:reply, resp, state}
  end

  def handle_info(:tick, state) do
    Logger.info("Tick for queue")
    {:noreply, state}
  end

  def handle_info({:update, :settings, new_list}, state), do: {:noreply, %{state | settings: new_list}}
  def handle_info({:update, :map_list, new_list}, state), do: {:noreply, %{state | map_list: new_list}}

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  # @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok, %{
      players: [],
      player_map: %{},
      last_wait_time: 0,
      id: opts.queue.id,
      map_list: opts.queue.map_list,
      settings: opts.queue.settings
    }}
  end

end
