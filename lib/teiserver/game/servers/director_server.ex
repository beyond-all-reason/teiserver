defmodule Teiserver.Game.DirectorServer do

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_info({:merge, new_map}, state) do
    new_state = Map.merge(state, new_map)
    {:noreply, new_state}
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok,
     %{
        battle_id: opts[:battle_id],
        game_mode: "team"
     }}
  end
end
