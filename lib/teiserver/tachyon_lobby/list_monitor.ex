defmodule Teiserver.TachyonLobby.ListMonitor do
  @moduledoc """
  Process that monitors all lobbies to broadcast the :remove_lobby events
  without having every subscriber to monitor all lobbies.
  """

  alias Teiserver.Helpers.PubSubHelper
  alias Teiserver.TachyonLobby.Lobby

  use GenServer

  require Logger

  def register(lobby_id, pid) do
    GenServer.call(__MODULE__, {:register, lobby_id, pid})
  end

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_arg) do
    Logger.metadata(actor_type: :lobby_list_monitor)
    state = %{monitors: %{}}
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register, lobby_id, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = put_in(state, [:monitors, ref], lobby_id)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, _map} ->
        Logger.warning("got DOWN with pid #{inspect(pid)} but no process registered")
        {:noreply, state}

      {lobby_id, rest} ->
        message = %{
          event: :remove_lobby,
          lobby_id: lobby_id
        }

        PubSubHelper.broadcast(Lobby.list_topic(), message)
        {:noreply, %{state | monitors: rest}}
    end
  end
end
