defmodule Teiserver.TachyonLobby.List do
  @moduledoc """
  This module provide listing and search for all lobbies currently live

  It is currently implemented with a GenServer to hold that list. Under heavy
  load, this may become problematic.
  The advantage is that it's easy to implement and prevent race conditions
  between subscription time and update events. It also allow for easy batching
  of events

  Later, if that GenServer becomes a bottleneck, we can partition the list and
  distribute the load across the partitions.
  """

  use GenServer

  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Lobby

  @type overview :: %{
          name: String.t(),
          player_count: non_neg_integer(),
          max_player_count: non_neg_integer(),
          map_name: String.t(),
          engine_version: String.t(),
          game_version: String.t()
        }

  @typep state :: %{
           monitors: MC.t(),
           lobbies: %{Lobby.id() => overview()}
         }

  @doc """
  New lobby should call this function so that they get listed
  """
  @spec register_lobby(pid(), Lobby.id(), overview()) :: :ok
  def register_lobby(lobby_pid, lobby_id, overview) do
    GenServer.cast(__MODULE__, {:register, {lobby_pid, lobby_id, overview}})
    :ok
  end

  @doc """
  list of all registered lobbies
  """
  # note: this may be relatively expensive to do when there are a lot of lobbies
  # would need to measure.
  # one potential optimisation would be to store the list of lobbies in an
  # ets table that can be directly read from other processes
  @spec list() :: %{Lobby.id() => overview()}
  def list() do
    GenServer.call(__MODULE__, :list)
  end

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  @spec init(term()) :: {:ok, state()}
  def init(_) do
    {:ok, %{monitors: MC.new(), lobbies: %{}}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, state.lobbies, state}
  end

  @impl true
  def handle_cast({:register, {lobby_pid, lobby_id, overview}}, state) do
    state =
      put_in(state, [:lobbies, lobby_id], overview)
      |> Map.update!(:monitors, &MC.monitor(&1, lobby_pid, lobby_id))

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _obj, _reason}, state) do
    lobby_id = MC.get_val(state.monitors, ref)

    state =
      Map.update!(state, :monitors, &MC.demonitor_by_val(&1, lobby_id))
      |> Map.update!(:lobbies, &Map.delete(&1, lobby_id))

    {:noreply, state}
  end
end
