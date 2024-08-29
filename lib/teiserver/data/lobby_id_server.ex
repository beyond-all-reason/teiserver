defmodule Teiserver.LobbyIdServer do
  @moduledoc """
  Used as a singleton to create lobby_ids and ensure we increment the counter
  each time across the cluster.
  """
  use GenServer

  @spec start_lobby_id_server() :: :ok | {:failure, String.t()}
  def start_lobby_id_server() do
    case get_server_pid() do
      nil ->
        {:ok, _coordinator_pid} =
          DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
            __MODULE__,
            name: __MODULE__, data: %{}
          })

        :ok

      _ ->
        {:failure, "Already started"}
    end
  end

  @spec get_next_id() :: {:error, :no_pid} | non_neg_integer()
  def get_next_id() do
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
  defp get_server_pid() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "LobbyIdServer") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], [])
  end

  def handle_call(:next_id, _from, state) do
    {:reply, state.next_id, %{state | next_id: state.next_id + 1}}
  end

  def handle_cast({:set_id, next_id}, state) do
    {:noreply, %{state | next_id: next_id}}
  end

  @spec init(map()) :: {:ok, map()}
  def init(_opts) do
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "LobbyIdServer",
      :lobby_id_server
    )

    {:ok,
     %{
       next_id: 1
     }}
  end
end
