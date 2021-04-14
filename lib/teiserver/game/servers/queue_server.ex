defmodule Teiserver.Game.QueueServer do
  use GenServer
  require Logger

  @tick_interval 5_000

  def handle_call({:add_player, userid, pid}, _from, state) when is_integer(userid) do
    {resp, new_state} = case Enum.member?(state.unmatched_players ++ state.matched_players, userid) do
      true ->
        {:duplicate, state}
      false ->
        player_item = %{
          join_time: :erlang.system_time(:seconds),
          pid: pid
        }
        new_state = %{state |
          unmatched_players: state.unmatched_players ++ [userid],
          player_count: state.player_count + 1,
          player_map: Map.put(state.player_map, userid, player_item
        )}
        {:ok, new_state}
    end
    {:reply, resp, new_state}
  end

  def handle_call({:remove_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} = case Enum.member?(state.unmatched_players ++ state.matched_players, userid) do
      true ->
        new_state = %{state |
          unmatched_players: Enum.reject(state.players, fn u -> u == userid end),
          matched_players: Enum.reject(state.players, fn u -> u == userid end),
          player_count: state.player_count - 1,
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
      player_count: state.player_count
    }
    {:reply, resp, state}
  end

  def handle_info(:tick, state) do
    # Typically we need to check things like team size and the like
    # but for this test of concept stage we're going to just assume we need two players

    # First make sure we have enough players...
    new_state = if Enum.count(state.unmatched_players) >= 2 do
      Logger.info("Attempting to match players")

      # Now grab the players
      [p1, p2 | new_unmatched_players] = state.unmatched_players
      player1 = state.player_map[p1]
      player2 = state.player_map[p2]

      # Count them as matched up
      new_matched_players = state.matched_players ++ [p1, p2]

      # Send them ready up commands
      send(player1.pid, {:matchmaking, {:match_ready, state.id}})
      send(player2.pid, {:matchmaking, {:match_ready, state.id}})

      %{state |
        unmatched_players: new_unmatched_players,
        matched_players: new_matched_players
      }
    else
      state
    end

    {:noreply, new_state}
  end

  def handle_info({:update, :settings, new_list}, state), do: {:noreply, %{state | settings: new_list}}
  def handle_info({:update, :map_list, new_list}, state), do: {:noreply, %{state | map_list: new_list}}

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    :timer.send_interval(@tick_interval, self(), :tick)

    {:ok, %{
      matchups: [],
      matched_players: [],
      unmatched_players: [],
      player_count: 0,
      player_map: %{},
      last_wait_time: 0,
      id: opts.queue.id,
      team_size: opts.queue.team_size,
      map_list: opts.queue.map_list,
      settings: opts.queue.settings
    }}
  end

end
