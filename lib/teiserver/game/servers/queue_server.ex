defmodule Teiserver.Game.QueueServer do
  use GenServer
  require Logger

  def handle_info({:add_player, userid}, state) do
    new_state = %{state | players: state.players ++ [{userid, :erlang.system_time(:seconds)}]}
    {:noreply, new_state}
  end

  def handle_info({:remove_player, userid}, state) do
    new_state = %{state | players: Enum.reject(state.players, fn {u, _} -> u == userid end)}
    {:noreply, new_state}
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
      last_wait_time: 0,
      id: opts.queue.id,
      map_list: opts.queue.map_list,
      settings: opts.queue.settings
    }}
  end

end
