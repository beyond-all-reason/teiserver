defmodule Teiserver.LobbyIdServer do
  @moduledoc """
  Used as a singleton to create lobby_ids and ensure we increment the counter
  each time across the cluster.
  """
  alias Horde.DynamicSupervisor, as: HordeSupervisor

  use GenServer, restart: :transient

  @spec start_lobby_id_server() :: :ok | {:failure, String.t()}
  def start_lobby_id_server do
    case get_server_pid() do
      nil ->
        # Another node may win the race and start the singleton first
        result =
          HordeSupervisor.start_child(Teiserver.SingletonSupervisor, {
            __MODULE__,
            name: __MODULE__, data: %{}
          })

        case result do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> {:failure, "Already started"}
        end

      _pid ->
        {:failure, "Already started"}
    end
  end

  @spec get_next_id() :: {:error, :no_pid} | non_neg_integer()
  def get_next_id do
    case get_server_pid() do
      nil -> {:error, :no_pid}
      pid -> GenServer.call(pid, :next_id)
    end
  end

  @spec set_next_id(non_neg_integer()) :: :ok | {:error, :no_pid}
  def set_next_id(next_id) do
    case get_server_pid() do
      nil -> {:error, :no_pid}
      pid -> GenServer.cast(pid, {:set_id, next_id})
    end
  end

  @spec get_server_pid() :: pid() | nil
  defp get_server_pid do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "LobbyIdServer") do
      [{pid, _data}] ->
        pid

      _not_found ->
        nil
    end
  end

  @spec start_link(list()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: via_tuple())
  end

  defp via_tuple do
    {:via, Horde.Registry, {Teiserver.ServerRegistry, "LobbyIdServer", :lobby_id_server}}
  end

  def handle_call(:next_id, _from, state) do
    {:reply, state.next_id, %{state | next_id: state.next_id + 1}}
  end

  def handle_cast({:set_id, next_id}, state) do
    {:noreply, %{state | next_id: next_id}}
  end

  # Another node won the singleton registration during a Horde registry
  # merge; step down cleanly so the :transient restart does not respawn us
  def handle_info({:EXIT, _from, {:name_conflict, _key, _registry, _winning_pid}}, state) do
    {:stop, :normal, state}
  end

  @spec init(map()) :: {:ok, map()}
  def init(_opts) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       next_id: 1
     }}
  end
end
