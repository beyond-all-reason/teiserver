defmodule Teiserver.SpringIdServer do
  @moduledoc """
  Used as a singleton to create spring_ids and ensure we increment the counter
  each time across the cluster.
  """
  use GenServer
  alias Teiserver.Account

  @spec start_spring_id_server() :: :ok | {:failure, String.t()}
  def start_spring_id_server() do
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

  @spec get_server_pid() :: pid() | nil
  defp get_server_pid() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "springIdServer") do
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

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "springIdServer",
      :spring_id_server
    )

    springids =
      Account.list_users(order_by: "Newest first", limit: 5, select: [:data])
      |> Enum.map(fn u -> Teiserver.Helper.NumberHelper.int_parse(u.data["springid"]) end)

    current_springid = Enum.max([0] ++ springids)

    {:ok,
     %{
       next_id: current_springid + 1
     }}
  end
end
