defmodule Teiserver.Game.BalancerServer do
  use GenServer
  require Logger
  # alias Teiserver.Data.Types, as: T
  # alias Teiserver.Battle.BalanceLib
  alias Teiserver.{Battle, Coordinator}
  alias Phoenix.PubSub

  @tick_interval 2_000

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end


  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end


  @impl true
  def handle_cast(:get_all, state) do
    {:noreply, state}
  end


  @impl true
  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :updated_client_battlestatus, _lobby_id, {_client, _reason}}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :add_user, _lobby_id, _userid}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, _, _, _}, state), do: {:noreply, state}

  def handle_info({:host_update, _userid, _host_data}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state) do
    {:noreply, state}
  end

  defp empty_state(lobby_id) do
    # it's possible the lobby is nil before we even get to start this up (tests in particular)
    # hence this defensive methodology
    lobby = Battle.get_lobby(lobby_id)

    founder_id = if lobby, do: lobby.founder_id, else: nil

    %{
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      host_id: founder_id,

      last_balance_hash: nil,
      balance_result: nil
    }
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "BalancerServer:#{lobby_id}",
      lobby_id
    )

    :timer.send_interval(@tick_interval, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
