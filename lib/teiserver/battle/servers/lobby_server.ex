defmodule Teiserver.Battle.LobbyServer do
  use GenServer
  require Logger
  # alias Phoenix.PubSub

  @impl true
  def handle_call(:lobby_state, _from, state) do
    {:reply, state.lobby, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_cast({:update_lobby, data}, state) do
    new_lobby = Map.merge(state.lobby, data)
    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:update_value, key, value}, state) do
    new_lobby = Map.put(state.lobby, key, value)
    {:noreply, %{state | lobby: new_lobby}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(state = %{lobby: %{id: id}}) do
    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.LobbyRegistry,
      id,
      id
    )

    {:ok, Map.put(state, :id, id)}
  end
end
